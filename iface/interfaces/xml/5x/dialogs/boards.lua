-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md, "The dialogs look"): 5.x's look of
-- the boards and mail (components/dialogs/bulletin.lua), from 5.33's own constructors, which are 7.5.2's older layout
-- (4a BulletinSession.cpp's non-EPF branches) to the pixel but for the rows' columns and the form's entries.
--
-- Every window but the form is 446 x 366 (InitBulletinDialogBounds 0x00407DF0), its DLGBBSnn.EPF frame 0 in NPAL8.PAL
-- (the labels are in the pictures), at placement slot 2 (centred on (320, 240): L.Place); the session's first window
-- slides open (DialogSession_PushDialog 0x00422FF0 calls 0x004208F0 for the first: X.SlideOpen). The buttons are 5.33's image
-- buttons, 72 x 16 (X.Image), the ids per control index 7.5.2's; the static texts 0x25, the edits 0x8F.
-- - The boards (BoardListDialog 0x004087C0, DLGBBS01): VIEW (1) (149, 316), QUIT (2) (226, 316); the list (36, 71)-
--   (410, 295) of 360 x 14 cells (BoardListPane_DrawListEntry 0x00408F40: the name in 0x8F, the selected row's 0x80 on
--   a 0x25 bar the cell wide).
-- - The article list (ArticleListDialog 0x00409040, DLGBBS02): VIEW, NEW, UP, DELETE, QUIT (1-5) along y 316 from x 37,
--   75 apart; the board's title (6) (131, 54)-(409, 66); the list (7) as the boards'; the extra UP (8) (34, 53). The mail
--   list (MailListDialog 0x0040D8B0, DLGBBS05): VIEW, NEW, REPLY, DELETE, UP (1-5) along y 316, QUIT (6) (187, 333); the
--   list (7). Their rows (ArticleListPane_DrawListEntry 0x0040AEF0, MailListPane's 0x0040F270): "%5d" the id, from x 60
--   the author (the sender) fitted to 80, from 150 "%2d/%2d" the date, from 200 the subject fitted to 160 (the mail's
--   110), in 0x8F (0x80 on the selected row's bar), 0x0E for an unread row.
-- - An article (ArticleDialog 0x0040B2A0, DLGBBS03): NEXT, NEW, UP, DELETE, PREV (1-5) along y 316, QUIT (6) (187, 333);
--   the heading (142, 54)-(410, 66), the author (111, 74)-(231, 86), the date (290, 74)-(410, 86), the subject (111, 93)-
--   (410, 106); the body (36, 115)-(410, 295), 0x8F wrapped at 362.
-- - A letter (MailDialog 0x0040F5B0, DLGBBS06): NEW, REPLY, DELETE, UP (1-4) along y 316 from x 74; NEXT, QUIT, PREV
--   (5-7) along y 333 from x 112; the sender (111, 84)-(231, 96), the date (290, 84)-(410, 96), the subject (111, 103)-
--   (410, 116); the body (36, 127)-(410, 295).
-- - The editor (NewArticleDialog 0x0040BF90, DLGBBS04): SEND (1) (149, 316), CANCEL (2) (226, 316); the heading (131, 54)-
--   (410, 66); the subject (131, 72)-(410, 85) and the body (36, 91)-(410, 295), edits (the bodies, the form's free text
--   and block values with their scroll bar at their right edge: X.EditBar, as 7.x's).
-- - A new letter (NewMailDialog 0x00410300, DLGBBS07): SEND, CANCEL; the recipient (111, 73)-(410, 85) (a reply's fixed
--   name in 0x25, else an edit), the subject (111, 93)-(410, 105), the body (36, 115)-(410, 295). 5.33 has no "keep a
--   copy" box: 5.x keeps 7.5.2's (control 6) with the base set's picture at (36, 316) (decision
--   2026-10-04-5x-merchant-trade-board-windows).
-- - The predefined form (NewPredefinedFormArticleDialog 0x0040C870, OnPaint 0x0040D630): 446 x (21 rows + 158), filled
--   in colour 0 then DLGBBS08's header (frame 0, 88 high), a row tile (frame 1, 16-430, 21 high) for each row and its
--   footer (frame 2, 70 high); SEND (0) and CANCEL (1) at (149, T) and (226, T), T = 21 rows + 108; the heading (131, 51)-
--   (410, 63), the subject (131, 71)-(410, 83); the entries from (36, 88), 21 a row, their values edits with 5.33's
--   border (SharedTextControlPaneOnPaint 0x0041BF00); the free form's field (36, 88)-(410, 21 rows + 88).
-- The windows with a default button draw DialogPane's Enter frames round it (X.Default).
--
-- Wire (the decision above): 5.33's lists show 16 rows of 14 (224 pixels), 7.5.2's article list 272 and its mail list
-- 280. When a list shows its end decides when older rows are asked for (3B 02: the kit's list:AtEnd); the component
-- gives the kit 7.5.2's own view of these lists for every look (bulletin.lua's list.logical, round 8), so the kit keeps
-- 7.5.2's position apart from 5.33's drawn one and they ask where 7.5.2's would however the drawn list scrolls. Nothing
-- here changes that. Drawing only: the indexes, the keys, the 3B requests and the replies are the renderer's and the
-- model's.
--
-- s6-ui-core (round 85): the XML twin's; the windows' sizes, pictures, buttons and the parts' places are boards.xml's
-- (core/xml.md).

local S = require("interfaces.5x.skin")
local unpack = table.unpack
local entry = require("interfaces.xml.entry")
local D = TK.Xml.Data("boards.xml")

return function(L, X)
    local P = "NPAL8.PAL"
    -- what 7.x's look draws alike: interfaces/original/boards.lua
    local B = require("interfaces.original.boards")(X)
    local first = B.First
    local BUTTON = D.BUTTON

    --- The window's frame (boards.xml's): its picture and its image buttons ({ index, image, left, top } each, BUTTON's
    --- size); its default: the index of the default button (DialogPane__SetFocusedControl), nil for none.
    local function frame(win, f)
        X.Art(win, f.file, P)
        for _, b in ipairs(f) do
            X.Image(win, win.controls[b[1]], b[2], b[3], b[4], b[3] + BUTTON.width, b[4] + BUTTON.height)
        end
        X.Default(win, f.default and win.controls[f.default] or nil)
    end

    --- The lists' place (boards.xml's LIST), with the boards' row colours.
    local function list(win)
        X.List(win, win.list, unpack(D.LIST))
        B.Colours(win.list)
    end

    local BD = D.Boards
    L.Boards = entry(BD, {
        slide = first,
        place = function(win)
            frame(win, BD.frame)
            list(win)
        end,
    })

    local BL = D.BoardList
    local COLUMNS = BL.columns
    L.BoardList = entry(BL, {
        slide = first,
        place = function(win)
            local mail = win.className == "MailListDialog"
            if mail then
                frame(win, BL.mail)
            else
                frame(win, BL.articles)
                B.Heading(win, unpack(BL.heading))
            end
            list(win)
            -- win.x5mail chooses the rows' subject width (7.5.2's view for the paging is the component's: above)
            win.x5mail = mail
        end,
        -- a row (the model's { status, id, author or sender, month, day, subject }): the columns above
        row = function(win, row, r)
            B.Row(row, r, COLUMNS.author, COLUMNS.date, COLUMNS.subject,
                  win.x5mail and COLUMNS.mailSubjectWidth or COLUMNS.subjectWidth)
        end,
    })

    local RD = D.Reader
    L.Reader = entry(RD, {
        slide = first,
        place = function(win)
            frame(win, RD.frame)
            B.Heading(win, unpack(RD.heading))
            local a, d, s = RD.author, RD.date, RD.subject
            X.StaticText(win, "x7author", a[1], a[2], a[3], a[4], S.LIST)
            X.StaticText(win, "x7date", d[1], d[2], d[3], d[4], S.LIST)
            X.StaticText(win, "x7subject", s[1], s[2], s[3], s[4], S.LIST)
            win.head:Hide()
            B.Body(win, unpack(RD.body))
        end,
        fill = B.Fill("author"),
    })

    local LT = D.Letter
    L.Letter = entry(LT, {
        slide = first,
        place = function(win)
            frame(win, LT.frame)
            local a, d, s = LT.author, LT.date, LT.subject
            X.StaticText(win, "x7author", a[1], a[2], a[3], a[4], S.LIST)
            X.StaticText(win, "x7date", d[1], d[2], d[3], d[4], S.LIST)
            X.StaticText(win, "x7subject", s[1], s[2], s[3], s[4], S.LIST)
            win.head:Hide()
            B.Body(win, unpack(LT.body))
        end,
        fill = B.Fill("sender"),
    })

    local F = D.Form
    local TILES, ENTRIES, BORDER = F.tiles, F.entries, F.border

    --- A value edit of the form with 5.33's border (SharedTextControlPaneOnPaint 0x0041BF00): its text 2 pixels in, a
    --- frame in 0x80 (S.TEXT) one pixel in, the outer edge's top and left in BORDER's light and its bottom and right in its
    --- dark; the lines are the edit's, so they hide with it. Drawing only.
    local function bordered(win, edit, l, t, r, b, bar)
        local place = bar and X.EditBar or X.Edit -- (a block value: its scroll bar at its right edge)
        place(edit, win, l + 2, t + 2, r - 2, b - 2, ENTRIES.ink)
        if not edit.x5border then
            local colours = { top = BORDER.light, left = BORDER.light, bottom = BORDER.dark, right = BORDER.dark }
            for side, outer in pairs(colours) do
                X.Line(edit, X.Solid(edit, "ARTWORK", outer), side, 2, true)
                X.Line(edit, X.Solid(edit, "ARTWORK", S.TEXT), side, 1, true)
            end
            edit.x5border = true
        end
    end

    --- One of the form's pictures (TILES' file, frame index at (x, y), masked, in NPAL8.PAL), kept by key for its next
    --- size.
    local function tile(win, key, index, x, y)
        win.x5tiles = win.x5tiles or {}
        win.x5tiles[key] = S.Picture(win, win.x5tiles[key], TILES.file, index, P, x, y, "BACKGROUND")
    end

    -- the predefined form: its entries laid out by 5.33's cursor (entryAt), its size and tiles by the rows they took (fit)
    L.Form = entry(F, {
        place = function(win)
            B.Heading(win, unpack(F.heading))
            local s, fr = F.subject, F.free
            X.Edit(win.subject, win, s[1], s[2], s[3], s[4], ENTRIES.ink)
            X.EditBar(win.free, win, fr[1], fr[2], fr[3], fr[4], ENTRIES.ink)
            win.x5fill = win.x5fill or X.Solid(win, "BACKGROUND", 0)
            win.x5fill:SetAllPoints(win)
        end,
        entrySize = B.EntrySize,
        -- the entries at 5.33's cursor from (36, ENTRIES.top) (B.EntryAt, 7.5.2's the same), their values edits with
        -- 5.33's border (a block value with its bar)
        entryAt = B.EntryAt(ENTRIES.top, bordered,
            function(w, edit, l, t, r, b) bordered(w, edit, l, t, r, b, true) end),
        nextEntry = B.NextEntry,
        -- the window by its rows: its tiles, SEND and CANCEL under them; it slides open when it is the session's first
        fit = function(win, free, count)
            local rows = B.FormRows(win, free, count)
            local h = TILES.row * rows + TILES.base
            local opened = win.opened
            X.Size(win, F.width, h)
            -- the header (frame 0) at the top, a row tile (frame 1) for each row, the footer (frame 2) under them
            for _, t in pairs(win.x5tiles or {}) do t:Hide() end
            tile(win, "header", 0, 0, 0)
            -- (the row tile at its frame's own left, (16, 0)-(430, 21): RenderTileFrame puts a frame at its rectangle)
            for k = 0, rows - 1 do tile(win, "row" .. k, 1, TILES.rowX, TILES.header + TILES.row * k) end
            tile(win, "footer", 2, 0, TILES.header + TILES.row * rows)
            local top = TILES.row * rows + TILES.buttons
            local send, cancel = F.send, F.cancel
            X.Image(win, win.controls[send[1]], send[2], send[3], top, send[3] + BUTTON.width, top + BUTTON.height)
            X.Image(win, win.controls[cancel[1]], cancel[2], cancel[3], top, cancel[3] + BUTTON.width, top + BUTTON.height)
            local fr = F.free
            if free then X.EditBar(win.free, win, fr[1], fr[2], fr[3], TILES.row * rows + TILES.header, ENTRIES.ink) end
            if opened and win.view and first(win, win.view) then X.SlideOpen(win) end
        end,
    })

    local E = D.Editor
    L.Editor = entry(E, {
        slide = first,
        place = function(win)
            frame(win, E.frame)
            B.Heading(win, unpack(E.heading))
            local s, b = E.subject, E.body
            X.Edit(win.subject, win, s[1], s[2], s[3], s[4], ENTRIES.ink)
            X.EditBar(win.body, win, b[1], b[2], b[3], b[4], ENTRIES.ink)
        end,
    })

    local N = D.NewMail
    L.NewMail = entry(N, {
        slide = first,
        place = function(win)
            frame(win, N.frame)
            local r, s, b = N.recipient, N.subject, N.body
            X.Edit(win.recipient, win, r[1], r[2], r[3], r[4], ENTRIES.ink)
            X.Text(win.fixed, win, r[1], r[2], r[3], r[4], S.LIST)
            X.Edit(win.subject, win, s[1], s[2], s[3], s[4], ENTRIES.ink)
            X.EditBar(win.body, win, b[1], b[2], b[3], b[4], ENTRIES.ink)
            -- keep a copy: 7.5.2's CheckBoxControlPane (the base set's picture: 5.33 has none) on the picture's free
            -- parchment left of SEND, its caption in 0x25 (the decision above)
            B.KeepCopy(win, N.keepCopy, N.keepCopyCaption, S.LIST)
        end,
    })
end
