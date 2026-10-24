-- s6-interface-5x-b (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md, "The dialogs look"): 5.x's look
-- of the user list and the friend list (components/dialogs/social.lua), 5.33's own windows by its own numbers. Drawing
-- only, but for where each control's press lands (its rectangle): the controls, their indexes, the keys, the 85 and 84
-- requests, the whisper and the friend list's OK are the renderers' and the model's, 7.5.2's, the same in every look.
--
-- The user list (UserListDialogPane_UserListDialogPane 0x004D0020): 635 x 390 on USERLIST.EPF in NPAL8.PAL, at its
-- placement slot 7 (centred on (320, 240) by 5.33's defaults, as the other 5.x windows: L.Place); CLOSE (1, image 15)
-- (529, 302)-(601, 318); the previous nation (19, image 44) (190, 302)-(262, 318), the next (16, image 45) (190, 321)-(262,
-- 337); the nation's name (36, 304)-(107, 316); the sort (3) (506, 37)-(568, 63), a radio group of two options, LEVEL at
-- (0, 0)-(59, 11) and NAME at (0, 16)-(59, 26), each RADIOBUT.EPF's frame 1 chosen, 0 not, at its left on its middle row;
-- the five columns (36 + 113 i, 102)-(146 + 113 i, 282), 96-pixel cells in 12-pixel rows (UserListPane's ListPane), each
-- with its count "%d" at (36 + 113 i, 285); the shown sum (111, 304) and the total (111, 323); the texts in 0x25, left
-- aligned. A row (UserListPane's DrawListEntry, 0x004D11A0): STAR.EPF's frame status - 1 centred on x 6, ICON.EPF's frame
-- (bucket - 1) x 4 + badge - 1 at x 13, both on the row's middle; the name right-aligned to the cell's right in its
-- colour, a friend's in 9; the selected row on a bar of its colour with the name in 0x80. 5.33's packet carries the same
-- three numbers in the same bits as 7.5.2's (the model's rows: SocialDialogs.cs, UserListDialogPane).
-- 7.5.2's own controls, which 5.33's window has not (the hunters' box 20 and hunters only 21), keep working where the
-- window leaves room: hunters only at (290, 304)-(400, 316) as a radio button with its caption, the hunters' box as a
-- text button (290, 321)-(374, 337). 7.5.2's hunter mark beside a name is not drawn (5.33's row has the star there).
--
-- The friend list (FriendListDialog_Constructor 0x00488CC0): 407 x 391 on FRIEND.EPF in NPAL8.PAL, slot 10 (centred); OK
-- (1, image 14) (168, 341)-(240, 357); the twenty names (2-21) at (104, 94 + 21 i)-(182, 106 + 21 i) and (246, ...)-(324,
-- ...), edits in 0x80.
--
-- s6-ui-core (round 85): the XML twin's; the windows' sizes, pictures and the parts' places are social.xml's
-- (core/xml.md).

local S = require("interfaces.5x.skin")
local unpack = table.unpack
local entry = require("interfaces.original.entry")
local D = TK.Xml.Data("social.xml")

return function(L, X)
    local C = TK.GetComponent("dialogs")
    local K = C.kit

    --- A 5.33 file's frame: its key and its whole frame's size (the rectangle 5.33's blits place), or nil.
    local function frameOf(file, frame, palette)
        local art, w, h = S.Image(file, frame, palette)
        if not art then return nil, 0, 0 end
        local ok, fw, fh = __tk:GetArtFrameSize(art)
        if ok then return art, fw, fh end
        return art, w, h
    end

    local radio = X.Radio

    local U = D.Users
    local COLUMNS, SUMS, ROW = U.columns, U.sums, U.row
    L.Users = entry(U, {
        place = function(win)
            X.Art(win, unpack(U.art))
            X.Image(win, win.close, unpack(U.close))
            X.Image(win, win.prev, unpack(U.prev))
            X.Image(win, win.next, unpack(U.next))
            local nl, nt, nr, nb = unpack(U.nation)
            X.Text(win.nation, win, nl, nt, nr, nb, S.LIST)
            win.nation:SetJustifyH("LEFT")
            win.nation:SetWordWrap(false)
            for c, list in ipairs(win.lists) do
                local l = COLUMNS.x + COLUMNS.step * (c - 1)
                X.List(win, list, l, COLUMNS.t, l + COLUMNS.width, COLUMNS.b, COLUMNS.cell)
                list.rowPainter = function(row, selected)
                    local r = row.x7record
                    if not r then return end
                    local colour = r[5] or S.LIST
                    if selected then S.Fill(row.sel, colour) end
                    row.text:SetTextColor(S.Colour(r[7] and ROW.friend or (selected and S.TEXT or colour)))
                end
                X.Text(win.counts[c], win, l, COLUMNS.countTop, l + COLUMNS.width, COLUMNS.countBottom, S.LIST)
                win.counts[c]:SetJustifyH("LEFT")
            end
            -- the shown sum (control 15) and the total (14)
            for key, t in pairs({ x5shown = SUMS.shown, x5total = SUMS.total }) do
                if not win[key] then win[key] = win:CreateFontString(nil, "OVERLAY") end
                X.Text(win[key], win, SUMS.l, t, SUMS.r, t + SUMS.height, S.LIST)
            end
            win.total:Hide()
            -- a hunter's note (the renderer's line): in control 18's place, in 0x80
            local ol, ot, orr, ob = unpack(U.note)
            X.Text(win.note, win, ol, ot, orr, ob, S.TEXT)
            win.note:SetWordWrap(false)
            -- the sort: the press anywhere on the group turns it over (the kit's switch, as 7.x's look)
            X.Rect(win.sort, win, unpack(U.sort))
            for _, part in ipairs({ win.sort.box, win.sort.check, win.sort.hl, win.sort.label }) do part:SetAlpha(0) end
            win.sort:HookScript("OnClick", function() L.Users.radio(win) end)
            -- 7.5.2's hunters only (21): a radio button and its caption over the kit's check box
            X.Rect(win.only, win, unpack(U.only))
            for _, part in ipairs({ win.only.box, win.only.check, win.only.hl }) do part:SetAlpha(0) end
            win.only.label:SetText(U.onlyLabel.text)
            local ll, lt, lr, lb = unpack(U.onlyLabel.rect)
            X.Text(win.only.label, win, ll, lt, lr, lb, S.TEXT)
            win.only:HookScript("OnClick", function() L.Users.radio(win) end)
            -- 7.5.2's hunters' box (20): the party search's editor, a text button of 5.33's
            win.party:SetText(U.partyButton.text)
            X.TextButton(win, win.party, unpack(U.partyButton.rect))
        end,
        -- the radio pictures by the switches (the sort: LEVEL the status order, NAME the name order)
        radio = function(win)
            local byName = win.sort:GetChecked()
            radio(win, "x5byStatus", not byName, unpack(U.byStatus))
            radio(win, "x5byName", byName, unpack(U.byName))
            radio(win, "x5only", win.only:GetChecked(), unpack(U.onlyRadio))
        end,
        -- a row ({ name, hunters flag, status, badge, colour, text, friend, bucket }): the star, the badge and the name
        -- right-aligned
        row = function(win, list, row, r)
            row.x7record = r
            row.text:SetText(K.Text(r[1]))
            row.text:SetJustifyH("RIGHT")
            row.text:SetWidth(ROW.width)
            -- the star centred on (starX, the row's middle) and the badge from iconX on the middle, by their frames' sizes
            local mid = math.floor(list.rowHeight / 2)
            local status, bucket, badge = r[3] or 0, r[8] or 0, r[4] or 0
            if status >= 1 and status <= 4 then
                local _, w, h = frameOf(ROW.star, status - 1)
                row.x5star = S.Picture(row, row.x5star, ROW.star, status - 1, nil, ROW.starX - math.floor(w / 2), mid - math.floor(h / 2))
            elseif row.x5star then
                row.x5star:Hide()
            end
            if bucket >= 1 and bucket <= 4 and badge >= 1 and badge <= 4 then
                local frame = (bucket - 1) * 4 + badge - 1
                local _, _, h = frameOf(ROW.icon, frame)
                row.x5icon = S.Picture(row, row.x5icon, ROW.icon, frame, nil, ROW.iconX, mid - math.floor(h / 2))
            elseif row.x5icon then
                row.x5icon:Hide()
            end
        end,
        fill = function(win, c)
            win.x5shown:SetText(string.format("%d", c.shown or 0))
            win.x5total:SetText(string.format("%d", c.total or 0))
            L.Users.radio(win)
        end,
    })

    local F = D.Friends
    local NAMES = F.names
    L.Friends = entry(F, {
        place = function(win)
            X.Art(win, unpack(F.art))
            X.Image(win, win.ok, unpack(F.ok))
            for i, e in ipairs(win.edits) do
                local col, row = (i - 1) // NAMES.perColumn, (i - 1) % NAMES.perColumn
                local l = NAMES.columns[col + 1]
                local t = NAMES.top + NAMES.step * row
                X.Edit(e, win, l, t, l + F.editWidth, t + F.editHeight, S.TEXT)
            end
        end,
    })
end
