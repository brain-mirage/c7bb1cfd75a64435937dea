-- s6-rules-dialogs: the user list and the party-search editor (behaviour.md D-57, D-58), and the friend list (D-59).
-- The list's records are social's (rules-items); a press on a hunter's row asks for its text (85), a double-click
-- whispers (the model's). Round 20 (K-109): the model picks the page's nation and fills the five columns; the window
-- draws them, one row selected in all of them.
--
-- s6-modular-g (interfaces): the windows' sizes and where their parts sit are the look's (C.look.Users,
-- PartySearch, Friends); this file keeps what each dialog does. A look may draw the user list's rows (Users.row) and its
-- own texts (Users.fill) its own way.

local C = TK.GetComponent("dialogs")
local K = C.kit
local W = TK.UI

-- D-57: Close (1), the sort (3), the five columns (4, 6, 8, 10, 12), the nation pages (19 <, 16 >), the hunters box
-- (20: the editor), hunters only (21). Field 0: the selected row's name.
-- Wire: UserListDialogPane::OnControlCommand 0x0059DA90 and HandleKeyOrTextEvent 0x0059D900 by these indexes, field 0
-- the selected name (the 85 request, the whisper); changing an index or the field changes what the server sees.
local Users = { look = "Users" }
local COLUMNS = { 4, 6, 8, 10, 12 }

function Users.build()
    local L = C.look.Users
    local win = K.Window(L.width, L.height, "Users")
    win.prev = K.Button(win, 19, "<", L.page)
    win.nation = W.Label(win, "", 13, W.white, "CENTER")
    win.next = K.Button(win, 16, ">", L.page)
    win.total = W.Label(win, "", 12, W.grey, "LEFT")
    win.lists, win.counts = {}, {}
    for c, index in ipairs(COLUMNS) do
        local list = K.List(win, index, L.columnWidth, L.columnHeight)
        -- UserListPane::OnItemSelected (0x0059ED20): a row picked in one column clears the others.
        list.onSelect = function()
            for _, other in ipairs(win.lists) do if other ~= list then other:Select(nil) end end
            win:ShowNote()
        end
        win.lists[c] = list
        win.counts[c] = W.Label(win, "", 12, W.grey, "CENTER")
    end
    win.note = K.Block(win, 12)
    win.sort = W.Check(win, "By name")
    win.controls[3] = win.sort
    K.Wire(win, win.sort, 3)
    win.only = W.Check(win, "Hunters only")
    win.controls[21] = win.only
    K.Wire(win, win.only, 21)
    win.party = K.Button(win, 20, "Party Search", L.party)
    win.close = K.Button(win, 1, "Close", L.button)
    --- The selected row ({ name, hunters flag, status, badge, colour, text }), whichever column holds it.
    function win:Selected()
        for _, list in ipairs(self.lists) do
            local i = list:First()
            if i then return list.items[i] end
        end
        return nil
    end
    function win:Values()
        local r = self:Selected()
        return { r and r[1] or "" }
    end
    function win:ShowNote()
        local r = self:Selected()
        self.note:SetText(r and r[6] and (r[1] .. " > " .. K.Text(r[6])) or "")
    end
    L.place(win)
    return win
end

function Users.update(win, view)
    local c = view.contents
    win.nation:SetText(K.Text(c.nation or ""))
    win.total:SetText(string.format("%d shown, %d online", c.shown or 0, c.total or 0))
    win.sort:SetChecked((c.sort or 0) == 1)
    win.only:SetChecked(c.huntersOnly and true or false)
    local keep = win:Selected()
    keep = keep and keep[1]
    for i, list in ipairs(win.lists) do
        local rows = (c.columns or {})[i] or {}
        list:SetItems(rows, function(row, r)
            row.text:SetText(((r[2] or 0) ~= 0 and "* " or "  ") .. K.Text(r[1]))
            -- s6-modular-g (interfaces, round 12): a look's own rows (7.x's: the marks, the name right-aligned)
            if C.look.Users.row then C.look.Users.row(win, list, row, r) end
        end)
        for k, r in ipairs(rows) do if r[1] == keep then list:Select(k) end end
        win.counts[i]:SetText(tostring((c.counts or {})[i] or 0))
    end
    win:ShowNote()
    -- s6-modular-g (interfaces, round 12): what a look draws of its own (7.x's: the sum and the total apart, the sort's
    -- two options); drawing only
    if C.look.Users.fill then C.look.Users.fill(win, c) end
end

function Users.key(win, key)
    if not win.view then return end
    for c, index in ipairs(COLUMNS) do
        if win.view.focus == index then return win.lists[c]:Key(key) end
    end
end

C.renderers.UserListDialogPane = Users

-- D-58: OK (1), the hunters box (2), the note (3). Fields: the box ("1" checked), the note.
-- Wire: PartySearchEditPane::OnControlCommand 0x0059E3D0 by these indexes with the two fields; changing them changes what
-- the server sees.
local Party = { look = "PartySearch" }

function Party.build()
    local L = C.look.PartySearch
    local win = K.Window(L.width, L.height, "Party Search")
    -- s6-modular-g (round 13 fix, Astra). Wire: the box is the kit's check box (CheckBoxControlPane), which toggles only
    -- on the release of a press 4a's dialog tracked: a double-click's second press (event 2, DialogPane::
    -- HandlePointerOrMouseEvent 0x0049E240) tracks none. A plain check button toggled at every release, so a double-click
    -- left it as it was and OK sent 84 00 where 4a sends 84 01; changing it changes the reply.
    win.hunters = K.Check(win, 2, "I am looking for a party")
    win.note = K.Edit(win, 3, L.editWidth, L.editHeight)
    win.note:SetMaxLetters(40)
    win.ok = K.Button(win, 1, "OK", L.button)
    function win:Values() return { self.hunters:GetChecked() and "1" or "", self.note:GetText() } end
    L.place(win)
    return win
end

function Party.update(win, view)
    if not win.opened then return end
    win.hunters:SetValue((view.contents.hunters or 0) ~= 0)
    K.SetEdit(win.note, view.contents.note or "")
end

C.renderers.PartySearchEditPane = Party

-- D-59: OK (1), the twenty names (2-21). Fields: the names.
-- Wire: FriendListDialog::OnControlCommand 0x0053F830: OK with the twenty names as the fields; changing them changes what
-- the server sees.
local Friends = { look = "Friends" }

function Friends.build()
    local L = C.look.Friends
    local win = K.Window(L.width, L.height, "Friends")
    win.edits = {}
    for i = 1, 20 do
        local e = K.Edit(win, i + 1, L.editWidth, L.editHeight)
        e:SetMaxLetters(64)
        win.edits[i] = e
    end
    win.ok = K.Button(win, 1, "OK", L.button)
    function win:Values()
        local out = {}
        for i = 1, 20 do out[i] = self.edits[i]:GetText() end
        return out
    end
    L.place(win)
    return win
end

function Friends.update(win, view)
    if not win.opened then return end
    local names = view.contents.names or {}
    for i = 1, 20 do K.SetEdit(win.edits[i], names[i] or "") end
end

C.renderers.FriendListDialog = Friends
