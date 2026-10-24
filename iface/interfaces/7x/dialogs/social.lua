-- s6-modular-g (interfaces, round 12): 7.x's look of the user list, the hunters-list settings and the friend list
-- (components/dialogs/social.lua), from Source-5's class pages (the EPF layout). Drawing only: the indexes, the keys,
-- the 85 and 84 requests and the whisper are the renderer's and the model's.
--
-- The user list (UserListDialogPane 0x0059BC90): 709 x 452 on USERLIST.EPF in USERLIST.PAL, at placement slot 8
-- (centred), sliding open; CLOSE (1, image 15) (608, 412); previous nation (19, 44) (7, 386), next (16, 45) (270, 386);
-- the nation's name (82, 391)-(154, 403); the sort (3: a radio group (379, 388)-(469, 432), its two options' RBUTTON.EPF
-- pictures at (379, 389) and (379, 417), frame 0 the chosen one, 1 the other); the five columns (16 + 135 i, 95)-(137 +
-- 135 i, 331) of 108 x 12 cells, each with its count "%d" at (89 + 135 i, 344); the shown sum (176, 391), the packet's
-- total (176, 419); the texts in 0x25. The hunters box (20) (530, 385)-(680, 409) and hunters only (21) (514, 13)-(642,
-- 37): check boxes with no caption, ONOFFBUT.EPF in BUTTON.PAL 4 and 3 pixels in (frame 1 checked). A row
-- (UserListPane::DrawListEntry 0x0059EA90): the hunter's mark (SYMBOLS.EPF frame 223) at x 0, the status star (STAR.EPF
-- frame status - 1) at x 12, the badge (ICON.EPF frame (bucket - 1) * 4 + badge - 1) at x 24, vertically centred;
-- the name right-aligned in its colour, selected text in 0x80 on a bar of the record's colour. A friend's name is
-- colour 9 after either selection state. The model supplies the friend flag and bucket along with the marks.
--
-- The hunters-list settings (PartySearchEditPane 0x0059E0D0): 338 x 190 on DLGSETUP.EPF in DLGSETUP.PAL, slot 3, sliding
-- open; OK (1, 14) (138, 156); the box (2) (16, 58)-(322, 82), captioned "Put me on the hunters list" from x 28; the note
-- (3) (16, 88)-(322, 126) in 0x80.
--
-- The friend list (FriendListDialog 0x0053F2C0): 332 x 399 on FRIEND.EPF in FRIEND.PAL, slot 11, sliding open; OK (1, 14)
-- (138, 363); the twenty names (2-21) at (49, 60 + 29 i)-(133, 72 + 29 i) and (199, ...)-(283, ...), edits in 0x80.
-- s6-ui-core (round 85): the XML twin's; the windows' pictures and the parts' places are social.xml's (core/xml.md).

local S = require("interfaces.7x.skin")
local unpack = table.unpack
local entry = require("interfaces.original.entry")
local D = TK.Xml.Data("social.xml")

return function(L, X)
    local K = TK.Dialogs
    local C = D.CHECK

    --- A picture of a file's frame on a texture (made once under key) at (l, t) of the window, its own size.
    --- For a centred badge, t is the row's middle; centre the whole native frame before adding its crop origin.
    local function picture(win, owner, key, file, frame, palette, l, t, centred)
        local tex = owner[key]
        if not tex then
            tex = owner:CreateTexture(nil, "ARTWORK")
            owner[key] = tex
        end
        local art, w, h = TK.Art.Image(file, frame, palette)
        tex:SetShown(art ~= nil)
        if not art then return tex end
        if centred then
            local ok, _, fh = __tk:GetArtFrameSize(art)
            t = t - math.floor((ok and fh or h) / 2)
        end
        local ox, oy = TK.Art.Origin(art)
        tex:SetTexture(art)
        tex:SetSize(w, h)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", win, "TOPLEFT", l + ox, -(t + oy))
        return tex
    end

    --- A check box of 4a's (CheckBoxControlPane / CheckBoxTextControlPane) over the kit's check: its rectangle takes the
    --- press, ONOFFBUT.EPF's frame 0 (frame 1 checked) 4 and 3 pixels in, its caption (if any) from x 28 in 0x80.
    local function check(win, box, rect, caption)
        local l, t, r, b = unpack(rect)
        X.Rect(box, win, l, t, r, b)
        local off, on = TK.Art.Image(C.file, 0, C.palette), TK.Art.Image(C.file, 1, C.palette)
        box.box:ClearAllPoints()
        box.box:SetPoint("TOPLEFT", box, "TOPLEFT", C.x, -C.y)
        box.box:SetSize(C.size, C.size)
        if off then box.box:SetTexture(off) end
        local mark = box.check
        mark:ClearAllPoints()
        mark:SetAllPoints(box.box)
        if on then mark:SetTexture(on) end
        box.hl:SetAlpha(0)
        box.label:SetShown(caption ~= nil)
        if caption then
            box.label:SetText(caption)
            X.Text(box.label, win, l + C.captionX, t + C.captionY, r, t + C.captionY + 12)
        end
    end

    local U = D.Users
    L.Users = entry(U, {
        place = function(win)
            X.Art(win, unpack(U.art))
            X.Image(win, win.close, unpack(U.close))
            X.Image(win, win.prev, unpack(U.prev))
            X.Image(win, win.next, unpack(U.next))
            local n = U.nation
            X.Text(win.nation, win, n[1], n[2], n[3], n[4], S.LIST)
            local col = U.columns
            for c, list in ipairs(win.lists) do
                local l = col.left + col.step * (c - 1)
                X.List(win, list, l, col.top, l + col.width, col.bottom, col.cell)
                list.rowPainter = function(row, selected)
                    local r = row.x7record
                    if not r then return end
                    local colour = r[5] or S.LIST
                    if selected then S.Fill(row.sel, colour) end
                    -- DrawListEntry (0x0059EA90): the friend colour overrides selected text, not its fill.
                    local textColour = selected and S.TEXT or colour
                    if r[7] then textColour = 9 end
                    row.text:SetTextColor(S.Colour(textColour))
                end
                X.Text(win.counts[c], win, l + col.count, col.countTop, l + col.count + col.countWidth, col.countTop + 12, S.LIST)
            end
            -- the shown sum (15) and the packet's total (14)
            local sums = U.sums
            for key, t in pairs({ x7shown = sums.shown, x7total = sums.total }) do
                if not win[key] then win[key] = win:CreateFontString(nil, "OVERLAY") end
                X.Text(win[key], win, sums.left, t, sums.right, t + 12, S.LIST)
            end
            win.total:Hide()
            -- a hunter's note: 4a prints it as a chat line ("%s > %s" in 0x8F: AddUserListSourceMessage); here the
            -- renderer's line, under the counts
            local note = U.note
            X.Text(win.note, win, note[1], note[2], note[3], note[4], S.LIST)
            win.note:SetWordWrap(false)
            -- the sort: a radio group of two options, the press anywhere on it (the kit's switch)
            X.Rect(win.sort, win, unpack(U.sort))
            for _, part in ipairs({ win.sort.box, win.sort.check, win.sort.hl, win.sort.label }) do part:SetAlpha(0) end
            win.sort:HookScript("OnClick", function() L.Users.radio(win) end)
            check(win, win.only, U.only)
            -- the hunters box (20): a check box without a caption over the kit's button, which keeps its press
            X.Rect(win.party, win, unpack(U.partyRect))
            for _, old in ipairs({ win.party.__normal, win.party.__pushed, win.party.__disabled }) do if old then old:Hide() end end
            if win.party:GetFontString() then win.party:GetFontString():Hide() end
            if win.party:GetHighlightTexture() then win.party:GetHighlightTexture():SetColorTexture(0, 0, 0, 0) end
            picture(win, win.party, "x7box", C.file, 0, C.palette, unpack(U.partyBox))
        end,
        -- the two options' pictures by the switch (frame 0 the chosen option, 1 the other)
        radio = function(win)
            local byName, r = win.sort:GetChecked(), U.radio
            picture(win, win, "x7byStatus", r.file, byName and 1 or 0, r.palette, unpack(U.byStatus))
            picture(win, win, "x7byName", r.file, byName and 0 or 1, r.palette, unpack(U.byName))
        end,
        -- a row ({ name, hunters flag, status, badge, colour, text, friend, bucket }): the marks and the name right-aligned
        row = function(win, list, row, r)
            row.x7record = r
            row.text:SetText(K.Text(r[1]))
            row.text:SetJustifyH("RIGHT")
            row.text:SetWidth(U.columns.cell)
            local hunter = (r[2] or 0) ~= 0
            local h = U.hunter
            local mark = picture(row, row, "x7hunter", h.file, h.frame, h.palette, h.x, 0)
            mark:SetShown(hunter and mark:GetTexture() ~= nil)
            local status = r[3] or 0
            local st = U.star
            local star = picture(row, row, "x7star", st.file, math.max(0, status - 1), st.palette, st.x, 0)
            star:SetShown(status >= 1 and status <= 4 and star:GetTexture() ~= nil)
            -- DrawListEntry (0x0059EA90): x24 and the native frame's height, before crop offsets.
            local bucket, badge = r[8] or 0, r[4] or 0
            if bucket >= 1 and bucket <= 4 and badge >= 1 and badge <= 4 then
                local bd = U.badge
                picture(row, row, "x7badge", bd.file, (bucket - 1) * 4 + badge - 1, bd.palette,
                    bd.x, math.floor(list.rowHeight / 2), true)
            elseif row.x7badge then
                row.x7badge:Hide() -- sorting/paging reuses rows; this record has no native badge
            end
        end,
        fill = function(win, c)
            win.x7shown:SetText(string.format("%d", c.shown or 0))
            win.x7total:SetText(string.format("%d", c.total or 0))
            L.Users.radio(win)
        end,
    })

    local P = D.PartySearch
    L.PartySearch = entry(P, {
        place = function(win)
            X.Art(win, unpack(P.art))
            X.Image(win, win.ok, unpack(P.ok))
            check(win, win.hunters, P.hunters, P.caption)
            local n = P.note
            X.Edit(win.note, win, n[1], n[2], n[3], n[4], S.TEXT)
        end,
    })

    local F = D.Friends
    L.Friends = entry(F, {
        place = function(win)
            X.Art(win, unpack(F.art))
            X.Image(win, win.ok, unpack(F.ok))
            local n = F.names
            for i, e in ipairs(win.edits) do
                local col, row = (i - 1) // n.rows, (i - 1) % n.rows
                local l, t = n.columns[col + 1], n.top + n.step * row
                X.Edit(e, win, l, t, l + n.width, t + n.height, S.TEXT)
            end
        end,
    })
end
