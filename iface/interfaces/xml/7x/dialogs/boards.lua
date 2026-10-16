-- s6-modular-g (interfaces, round 12): 7.x's look of the boards and mail (components/dialogs/bulletin.lua), from
-- Source-5's class pages (the EPF layout, which this build always takes). Drawing only: the indexes, the keys, the 3B
-- requests and the replies are the renderer's and the model's.
--
-- Every window is 451 x 420 (InitBulletinDialogBounds 0x004712B0), on its DLGBBSnn.EPF in DLGBBSnn.PAL, at placement
-- slot 2 (centred, as every slot but 13); DialogSession::PushDialog (0x004A0FC0) plays sample 0x198 for each and slides
-- open only the session's first (L.Open, entry.slide). The buttons are 4a's image buttons, 63 x 24:
-- - the boards (BoardListDialog 0x00472070, DLGBBS01): OPEN (1, image 17) (144, 381), CLOSE (2, 15) (231, 381); the list
--   (25, 56)-(430, 356) of 360 x 14 cells (BoardListPane::DrawListEntry 0x00472B70: the name in 0x8F, the selected row's
--   on a 0x25 bar the cell wide in 0x80);
-- - an article list (ArticleListDialog 0x00472CA0, DLGBBS02): READ (1, 17), WRITE (2, 32), BACK (3, 31), DELETE (4, 21),
--   CLOSE (5, 15) along y 381-405 from x 37, 75 apart; the board's title (6) (94, 59)-(404, 71) in 0x25; the list (7)
--   (25, 85)-(430, 357) of 380 x 14 cells; the extra button (8, 31) (348, 53);
-- - the mail list (MailListDialog 0x00479110, DLGBBS05): READ (1, 17), WRITE (2, 32), REPLY (3, 33), DELETE (4, 21),
--   BACK (5, 31) along y 356-380 from x 37, CLOSE (6, 15) (187, 386); the list (7) (25, 56)-(430, 336) of 360 x 14 cells;
--   the list rows (ArticleListPane::DrawListEntry 0x00474F90, MailListPane's 0x0047AE50): "%5d" the id, from x 35 the
--   author (the sender) fitted to 80 pixels with "...", from 110 "%2d/%2d" the date, from 150 the subject fitted to 208,
--   in 0x8F (0x80 on the selected row's 0x25 bar), 0x0E for a row whose status (unread) byte is set;
-- - an article (ArticleDialog 0x004753E0, DLGBBS03): buttons 1-5 (19, 32, 31, 21, 18) along y 356-380 from x 37, CLOSE
--   (6, 15) (187, 386); the heading (94, 58)-(406, 70), the author (94, 85)-(214, 97), the date (309, 85)-(405, 97), the
--   subject (94, 112)-(406, 124), all in 0x25; the body (11) (25, 139)-(430, 339), 0x8F, wrapped at 379;
-- - a letter (MailDialog 0x0047B220, DLGBBS06): WRITE (1, 32), REPLY (2, 33), DELETE (3, 21), BACK (4, 31) along y
--   356-380 from x 59, 85 apart; next (5, 19), CLOSE (6, 15), previous (7, 18) along y 386-410 from x 102; the sender
--   (94, 59)-(214, 71), the date (310, 59)-(430, 71), the subject (94, 86)-(406, 98) in 0x25; the body (25, 112)-(430, 336);
-- - the editor (NewArticleDialog 0x00476C10, DLGBBS04): SEND (1, 23) (144, 381), CANCEL (2, 22) (231, 381); the heading
--   (94, 58)-(406, 70) in 0x25; the subject (94, 85)-(406, 97) and the body (25, 112)-(430, 356), edits in 0x8F, the
--   body with its scroll bar at its right edge (X.EditBar; s6-interface-7x round 2, as the new letter's and the
--   predefined form's free text and block entries);
-- - a new letter (NewMailDialog 0x0047D050, DLGBBS07): SEND (1, 23) (144, 381), CANCEL (2, 22) (231, 381); the recipient
--   (94, 58)-(406, 70) (a reply's fixed name in 0x25, else an edit), the subject (94, 85)-(406, 97), the body
--   (25, 112)-(430, 356), edits in 0x8F; keep a copy (6) ONOFFBUT.EPF in BUTTON.PAL (frame 1 checked, 0 not) 16 x 16 at
--   (36, 384), its caption "Keep a copy" at (56, 386) in 0x80.
-- - the predefined form (NewPredefinedFormArticleDialog 0x004777A0): 450 x (25 rows + 204), rows its visible rows
--   (DeserializePredefinedFormArticleEntries: one for each entry that ends its row, 16 x lines / 21 + 1 more for each
--   block entry, in a byte; 5 for the free form): DLGBBS08.EPF in DLGBBS08.PAL, its header (tile 0, 120 high), a row tile
--   (1, 25 high) for each row and its footer (2, 84 high) (OnPaint 0x00478380); SEND (0, image 23) and CANCEL (1, 22) at
--   (149, T) and (226, T), T = 25 rows + 139; the heading (94, 59)-(404, 71) in 0x25, the subject (94, 86)-(404, 98); the
--   entries from (36, 110): a label as wide as its text in 0x25, then an inline value as wide as its label (4a's own
--   rectangle), the next from 6 x lines + 5 further or, ending its row, 21 lower at 36; a block value 21 lower at
--   (36, y)-(400, y + 16 lines), the next 21 x (16 lines / 21 + 1) lower; the free form's one field (36, 110)-(410, 25 rows
--   + 110). Edits in 0x8F. It slides open when it is the session's first.
-- s6-ui-core (round 85): the XML twin's; the windows' pictures, buttons, lists and the parts' places are boards.xml's
-- (core/xml.md).

local S = require("interfaces.7x.skin")
local unpack = table.unpack
local entry = require("interfaces.xml.entry")
local D = TK.Xml.Data("boards.xml")

return function(L, X)
    -- what 5.x's look draws alike: interfaces/original/boards.lua
    local B = require("interfaces.original.boards")(X)
    local first = B.First
    local EDIT = D.EDIT

    --- The window's picture and its image buttons (boards.xml's window: its file, and { index, image, x, y } each,
    --- 63 x 24).
    local function frame(win, w)
        X.Art(win, w.file, (w.file:gsub("EPF$", "PAL")))
        for _, b in ipairs(w) do
            X.Image(win, win.controls[b.index], b.image, b.x, b.y, b.x + 63, b.y + 24)
        end
    end

    local BO = D.Boards
    L.Boards = entry(BO, {
        slide = first,
        place = function(win)
            frame(win, BO.window)
            X.List(win, win.list, unpack(BO.window.list))
            B.Colours(win.list)
        end,
    })

    -- An article list or the mail list, by the class being built.
    -- Wire (Astra's review of round 12): these two lists page. Their 14-pixel rows (ListPane's m_cellSize.y) and their
    -- rectangles' heights (the mail's 280, twenty rows exactly; the articles' 272: boards.xml's) are 4a's, and they
    -- decide when a list shows its end: ListPane::GetScrollRange (0x004F3F20) and the position a wheel notch or the bar
    -- moves by a row, the older rows asked for (3B 02) when the position meets the range
    -- (MailListPane::HandlePointerOrMouseEvent 0x0047AD80, ArticleListPane's 0x00474EC0; the kit's list:AtEnd). Changing
    -- a row's height or a list's rectangle changes when the client asks for older mail or articles.
    local BL = D.BoardList
    L.BoardList = entry(BL, {
        slide = first,
        place = function(win)
            if win.className == "MailListDialog" then
                frame(win, BL.mail)
                X.List(win, win.list, unpack(BL.mail.list))
            else
                frame(win, BL.articles)
                B.Heading(win, unpack(BL.articles.heading))
                X.List(win, win.list, unpack(BL.articles.list))
            end
            B.Colours(win.list)
        end,
        -- a row (the model's { status, id, author or sender, month, day, subject }): the columns above
        row = function(win, row, r) B.Row(row, r, BL.row.author, BL.row.date, BL.row.subject, BL.row.width) end,
    })

    local R = D.Reader
    L.Reader = entry(R, {
        slide = first,
        place = function(win)
            frame(win, R.window)
            B.Heading(win, unpack(R.heading))
            X.StaticText(win, "x7author", R.author[1], R.author[2], R.author[3], R.author[4], S.LIST)
            X.StaticText(win, "x7date", R.date[1], R.date[2], R.date[3], R.date[4], S.LIST)
            X.StaticText(win, "x7subject", R.subject[1], R.subject[2], R.subject[3], R.subject[4], S.LIST)
            win.head:Hide()
            B.Body(win, unpack(R.body))
        end,
        fill = B.Fill("author"),
    })

    local LE = D.Letter
    L.Letter = entry(LE, {
        slide = first,
        place = function(win)
            frame(win, LE.window)
            X.StaticText(win, "x7author", LE.author[1], LE.author[2], LE.author[3], LE.author[4], S.LIST)
            X.StaticText(win, "x7date", LE.date[1], LE.date[2], LE.date[3], LE.date[4], S.LIST)
            X.StaticText(win, "x7subject", LE.subject[1], LE.subject[2], LE.subject[3], LE.subject[4], S.LIST)
            win.head:Hide()
            B.Body(win, unpack(LE.body))
        end,
        fill = B.Fill("sender"),
    })

    -- the predefined form: its entries laid out by 4a's cursor (entryAt), its size and tiles by the rows they took (fit)
    local F = D.Form
    local function editBar(w, edit, l, t, r, b) X.EditBar(edit, w, l, t, r, b, EDIT) end
    L.Form = entry(F, {
        place = function(win)
            B.Heading(win, unpack(F.heading))
            local s = F.subject
            X.Edit(win.subject, win, s[1], s[2], s[3], s[4], EDIT)
            editBar(win, win.free, unpack(F.free))
        end,
        entrySize = B.EntrySize,
        -- the entries at 4a's cursor from (36, 110) (B.EntryAt), their values edits in 0x8F
        entryAt = B.EntryAt(F.entries,
            function(w, edit, l, t, r, b) X.Edit(edit, w, l, t, r, b, EDIT) end,
            editBar),
        nextEntry = B.NextEntry,
        -- the window by its rows: its tiles, SEND and CANCEL under them; it slides open when it is the session's first
        fit = function(win, free, count)
            local rows = B.FormRows(win, free, count)
            local t = F.tiles
            local h = t.header + t.row * rows + t.footer
            local opened = win.opened
            X.Size(win, F.width, h)
            local tile = X.Tiler(win)
            tile(t.file, 0, t.palette, 0, 0, F.width, t.header)
            for k = 0, rows - 1 do tile(t.file, 1, t.palette, 0, t.header + t.row * k, F.width, t.row) end
            tile(t.file, 2, t.palette, 0, t.header + t.row * rows, F.width, t.footer)
            local top = t.header + t.row * rows + t.buttons
            for _, b in ipairs(F.buttons) do
                X.Image(win, win.controls[b.index], b.image, b.x, top, b.x + 63, top + 24)
            end
            if free then
                local f = F.free
                editBar(win, win.free, f[1], f[2], f[3], t.row * rows + F.entries)
            end
            if opened and win.view and first(win, win.view) then X.SlideOpen(win) end
        end,
    })

    local E = D.Editor
    L.Editor = entry(E, {
        slide = first,
        place = function(win)
            frame(win, E.window)
            B.Heading(win, unpack(E.heading))
            local s = E.subject
            X.Edit(win.subject, win, s[1], s[2], s[3], s[4], EDIT)
            editBar(win, win.body, unpack(E.body))
        end,
    })

    local N = D.NewMail
    L.NewMail = entry(N, {
        slide = first,
        place = function(win)
            frame(win, N.window)
            local r, s = N.recipient, N.subject
            X.Edit(win.recipient, win, r[1], r[2], r[3], r[4], EDIT)
            X.Text(win.fixed, win, r[1], r[2], r[3], r[4], S.LIST)
            X.Edit(win.subject, win, s[1], s[2], s[3], s[4], EDIT)
            editBar(win, win.body, unpack(N.body))
            -- keep a copy (6), its caption in 0x80
            B.KeepCopy(win, N.keepCopy, N.keepCopyCaption)
        end,
    })
end
