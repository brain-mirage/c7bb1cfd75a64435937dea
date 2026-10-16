-- s6-ui-core (round 86; the owner, 2026-10-12: 7.x and 5.x get the real client's whole interface, "login, character
-- creation" included, behind a setting beside Enable XML Interface, off by default; decision
-- 2026-10-12-original-pregame-screens): an original client's title screen, the twins' shared script for it. Each
-- interface's own file (interfaces/xml/7x/screens/title.lua, interfaces/xml/5x/screens/title.lua) gives its layout
-- (its title.xml, beside it) and its kit, and this makes the presentation over the login's logic (core/login.lua, "an
-- interface's own login screen"). 7.5.2's MainMenuPane (0x004F6700) and 5.33's (0x457250) have the same six entries
-- and the same Login dialog (LoginDialogPane: 7.5.2's 0x004FA7A0, 5.33's 0x45A0C0); their pictures, places and sizes
-- are the layouts'. Shared by the twins as interfaces/xml/entry.lua is.
--
-- The menu (MainMenuPane): entry 1 (Login) is highlighted as it opens. A pointer move over an entry highlights it (a move
-- over no entry keeps the highlight), and a left release anywhere on the menu activates the highlighted entry after the
-- same move (HandlePointerOrMouseEvent 0x004F6AF0). Up and Left highlight the entry before, Down and Right the one after,
-- wrapping, and Enter activates (HandleKeyOrTextEvent 0x004F6BF0). 5.33's are the same (s6-ui-core round 86, read in
-- its code): its pointer handler 0x458240 and key handler 0x458520 test the same rectangles, event types and keys, and
-- activate through the same switch (0x4574E0 is that switch alone). The entries (ActivateMenuItem 0x004F7A10; 5.33's
-- the same, its Story and History books STORY.EPF and HISTORY.EPF): 0 a new account, 1 the login dialog,
-- 2 Change Password, 3 Story, 4 History, 5 Exit; 0 opens the original's New User dialog (below); 0 and 2 need the
-- connection, as ours do (the original's menu exists only once connected).
--
-- Change Password (ChangePasswordDialogPane: 7.5.2's 0x004FDD40, its EPF layout; 5.33's 0x45CD00, the non-EPF one):
-- core/login.lua's dialog (L:OpenChangePassword) in the original's look, its layout the interface's PASSWORD. The
-- account field has the keyboard as it opens (SetHoverControl(3)), the other three are masked, OK is its focused
-- control, and OK's state is the logic's (UpdateActionButton 0x004FE490: both new fields filled). It opens with the
-- dialogs' sound 0x198; its slide is not drawn. Escape, which the menu ignores, opens
-- Settings: the way back to the setting.
--
-- The alerts (AlertPane, 0x0049FEB0; 5.33's 0x00421BA0 has the same numbers): core/login.lua's L:Alert in the original's
-- look (P.ShowAlert): a refusal's message (LoginDialogPane::HandlePacketEvent 0x004FAB10: AlertPane(message, this,
-- L"OK", 0)), Change Password's answers and the version's refusal. Drawing only: OK, Enter and Escape close it through
-- L:CloseAlert, whose timing is the session's, and nothing is sent.
--
-- The connect screen (TerminalPane: 7.5.2's constructor 0x0058AF50 and OnTimer 0x0058B470; 5.33's 0x4BB0F0 and 0x4BB2A0
-- the same): the screen black while a connection starts from the title (core/login.lua's presentation Terminal), with
-- AlertPane(string 156) and no button during the connect; then black alone until the greeting's hand-over, when the menu
-- shows; on a failure VersatileAlertPane(string 157, "Reconnect", "Leave"), Reconnect the Enter button and Leave the
-- Escape one (its callback 0x0058B620, 5.33's 0x4BB410: 1 starts timer 0 again, 0 RequestExit). Each alert opens with
-- 0x198 (DialogPane::AddToLayer); its slides are not drawn. Drawing only: the connect, its stalls and the hand-over's
-- packets are the session's (TK-Core Session.Login.cs, OnTerminalTimer), and its sample 401 the audio's.
--
-- The login dialog (LoginDialogPane): the account field holds the last account and has the keyboard as it opens
-- (SetHoverControl(3)); the password field is empty; OK is enabled only while both hold text (UpdateActionButton
-- 0x004FAE30) and is the dialog's focused control (the interface's focus mark). Enter is OK and Escape is Cancel
-- (SetFocusedControl(1), SetPendingControl(2)), each shown pressed for 133 ms first as in every dialog here (byKey,
-- below), and Cancel only closes it (OnControlCommand 0x004FAD00's case 2). A
-- pointer event outside it reaches the menu (HandlePointerOrMouseEvent 0x004FAE90). It opens with the dialogs' sound
-- 0x198 (DialogPane::AddToLayer; 5.33's DialogPane_AddToLayer 0x41fca0 the same). Its slide (SlideOpenVertical) is not
-- drawn.
--
-- WIRE: OK is core/login.lua's L:LoginButton, our Login button's entry. The login's bytes, its 200-599 ms wait (the
-- Sleep in LoginDialogPane::SendLoginRequest 0x004FB2D0, which OnControlCommand 0x004FAD00 calls) and the replies stay
-- the session's (Session.Login.cs); the account and password are read from this dialog's fields. Enter reaches OK
-- 133 ms after the key (byKey: DialogPane::ActivateDefaultControl's Sleep(133)), a click at once. After OK the screen is dimmed and takes every press and key until the answer (ScreenDimmer(5), made at
-- 0x004FAD00 and deleted on a refusal by HandlePacketEvent 0x004FAB10), so nothing more is sent meanwhile; changing this
-- changes what the server sees. The other entries send what ours send (their own paths in core/login.lua): Change
-- Password's OK and Enter are L:SubmitPassword, which checks the form and sends 0x26 as SubmitPasswordChange
-- (0x004FE560) does, the screen dimmed until the answer (ScreenDimmer(5)), so one request goes.

--- The title for an interface's kit:
---   data, load        its title.xml's data (TK.Xml.Data) and its loader (opts -> TK.Xml.Load's result), read beside the
---                     interface's file;
---   S, X, elements    its skin (S.Picture, S.Text), its dialog kit (X.Edit, X.Image, X.PlaceAt, X.ScreenPoint: the
---                     original client's, interfaces/original/dialogkit.lua, at its screen) and its XML elements;
---   focus(button)     marks OK as the dialog's focused control, as the interface draws that;
---   available()       optional: false when its pictures' set is missing (ours shows then);
---   book              optional: its Story and History books' own pages and turn (core/login.lua's presentation book).
--- Returns core/login.lua's module function(L, screen), which makes the presentation (nil: ours shows).
return function(kit)
    local S, X, D = kit.S, kit.X, kit.data
    local ITEMS = D.ITEMS

    --- Entry i's rectangle on the screen, right and bottom outside it (ComputeMenuItemRect 0x004F8B90).
    local function itemRect(i)
        return ITEMS.left, ITEMS.top + ITEMS.step * i, ITEMS.right, ITEMS.bottom + ITEMS.step * i
    end

    --- The entry at a point of the screen, or nil (MainMenuHitTest 0x004F8C10).
    local function entryAt(x, y)
        for i = 0, ITEMS.count - 1 do
            local l, t, r, b = itemRect(i)
            if x >= l and x < r and y >= t and y < b then return i end
        end
    end

    --- The presentation for core/login.lua (its contract there): L the login's logic, screen ours (the parent).
    return function(L, screen)
        if kit.available and not kit.available() then return nil end
        local P = { book = kit.book }
        local scripts = {}
        local selected = ITEMS.first
        local lastX, lastY -- the pointer's place at the last look, so only a move highlights (not a key's change undone)
        local page, dialog

        -- Enter and Escape in a dialog (DialogPane::ActivateDefaultControl 0x0049DE70 and ActivatePendingControl
        -- 0x0049DF20; 5.33's the same, inline in DialogPane_HandleKeyOrTextEvent 0x420560 at 0x4206A2 and 0x42073E): the
        -- dialog's default (or cancel) button shows pressed for 133 ms (Sleep(133) on the main thread), then its command
        -- runs, all inside the key; only an enabled button, and a click runs its command at once.
        -- WIRE (round 92's final review, P1): the 133 ms is the session's (L:DialogKeyPressed: Session.DialogKeyPressed),
        -- called in the key's place before the command, whose own session call then rides the same key after it. So the
        -- command's packet (the login's 0x03 after its own wait, the creation's 0x02, Change Password's 0x26) follows the
        -- key by 133 ms, and the menu's timers (its keep-alive 0x71) and any later click or key wait behind it, as the
        -- original's sleep holds them. Deferring the command here instead (a frame timer) would let those slip in first;
        -- changing this changes the order and timing the server sees. The pressed look is drawing only: it shows for the
        -- same 133 ms on the clock (GetTime) while the command has already run (a closing dialog closes at once; the
        -- login's OK keeps its look meanwhile, P.Refresh).
        local pressing -- { button, at } while a key's pressed look shows
        local presser
        local function byKey(button, command)
            if not button:IsEnabled() then return end
            if pressing then pressing.button:SetButtonState("NORMAL") end
            pressing = { button = button, at = GetTime() + 0.133 }
            button:SetButtonState("PUSHED")
            if not presser then
                presser = CreateFrame("Frame", nil, screen)
                presser:SetScript("OnUpdate", function(self)
                    if GetTime() < pressing.at then return end
                    local b = pressing.button
                    pressing = nil
                    self:Hide()
                    b:SetButtonState("NORMAL")
                    P.Refresh()
                end)
            end
            presser:Show()
            L:DialogKeyPressed()
            command()
        end

        local function highlight(i)
            selected = i
            page.selected = i -- (what the tests read)
            local l, t = itemRect(i)
            S.Picture(page, page.selection, ITEMS.selected, i, ITEMS.selectedPalette, l, t)
        end

        -- the entries, by their index (ActivateMenuItem)
        local ENTRIES = {
            [0] = function() if L.connected and not L.busy then L:ShowCreate() end end,
            [1] = function() P.OpenDialog() end,
            [2] = function() if L.connected and not L.busy then L:OpenChangePassword() end end,
            [3] = function() L:OpenBook("STORY.EPF") end,
            [4] = function() L:OpenBook("HISTORY.EPF") end,
            [5] = function() L:Quit() end,
        }

        local function activate() ENTRIES[selected]() end

        --- The highlight follows the entry under the pointer at (px, py) in UIParent units; none keeps it.
        local function follow(px, py)
            local i = entryAt(X.ScreenPoint(px, py))
            if i and i ~= selected then highlight(i) end
        end

        -- each entry's own picture where the menu has one (7.5.2's TITLEBUT; 5.33's title has them in its picture)
        function scripts.Items(f)
            if ITEMS.file then
                for i = 0, ITEMS.count - 1 do
                    local l, t = itemRect(i)
                    S.Picture(f, nil, ITEMS.file, i, ITEMS.palette, l, t, "ARTWORK")
                end
            end
            f.selection = f:CreateTexture(nil, "OVERLAY")
        end

        function scripts.Dialog(d)
            local c = D.DIALOG
            X.Edit(d.account, d, table.unpack(c.account))
            X.Edit(d.password, d, table.unpack(c.password))
            d.account:SetMaxLetters(L.MAX_ACCOUNT)
            d.password:SetMaxLetters(c.maxPassword)
            d.password:SetPassword(true)
            X.Image(d, d.ok, c.ok.id, table.unpack(c.ok.rect))
            X.Image(d, d.cancel, c.cancel.id, table.unpack(c.cancel.rect))
            kit.focus(d.ok)
            d.ok:SetScript("OnClick", function() P.OK() end)
            d.cancel:SetScript("OnClick", function() P.Cancel() end)
            for _, box in ipairs({ d.account, d.password }) do
                box:SetScript("OnEnterPressed", function() if not L.busy then byKey(d.ok, P.OK) end end)
                box:SetScript("OnEscapePressed", function() if not L.busy then byKey(d.cancel, P.Cancel) end end)
                box:SetScript("OnTextChanged", function() P.Refresh() end)
                -- the field that had the keyboard last, for a book or an alert to give it back (core/login.lua)
                box:HookScript("OnEditFocusGained", function(self) screen.lastField = self end)
            end
        end

        -- Change Password's layout (its fields, OK and Cancel; the logic's: core/login.lua's L.WirePasswordDialog)
        function scripts.Password(d)
            local c = D.PASSWORD
            for i, k in ipairs({ "account", "current", "new", "again" }) do
                X.Edit(d[k], d, table.unpack(c[k]))
                d[k]:SetPassword(i > 1)
            end
            X.Image(d, d.ok, c.ok.id, table.unpack(c.ok.rect))
            X.Image(d, d.cancel, c.cancel.id, table.unpack(c.cancel.rect))
            kit.focus(d.ok)
            d.ok:SetScript("OnClick", function() L:SubmitPassword() end)
            d.cancel:SetScript("OnClick", function() L:CloseChangePassword() end)
            d:SetScript("OnShow", function() TK.Game.Sound.PlayEffect(0x198) end)
        end

        -- ----- the New User dialog (CreateUserDialogPane 0x0052DD30; where the interface's title.xml has one) -----
        -- Its layout and look; its logic is core/login.lua's (the presentation's createDialog): L:ShowCreate fills it and
        -- sets its look and facing, OK is L:SubmitCreate, Cancel L:CancelCreate. Its look's controls change the look and
        -- draw it again; nothing of it is sent before OK (WIRE: what OK sends is the logic's, from the look).
        --
        -- Its keyboard (7.x's, d.stops): the controls that take focus, in their order, are the three fields, then the hair
        -- and the face colour lists (the grids and the picture buttons take none: constructed with 0); Tab goes to the next,
        -- Shift+Tab to the one before, round (DialogPane::FocusNextControl, FocusPreviousControl). A focused list shows
        -- nothing (ScrollableControlPane::OnPaint draws no focus with the EPF art) and its arrows step it. A press on a
        -- control that takes focus moves it there; a press on one that takes none leaves it where it was (DialogPane's
        -- press: SetHoverControl only for a control that can take focus), so the field typed in keeps the keyboard.

        --- The stops' focus marks: the image buttons among them (5.x's OK and Cancel, stop.takesEnter) show the
        --- interface's focus frame while they are the stop (ImageButton's paint, 5.33 0x00419760). Drawing only.
        local function markStop(d)
            if not kit.focus then return end
            for i, s in ipairs(d.stops) do
                if s.takesEnter then kit.focus(s, i == d.stop) end
            end
        end

        --- The stop i has the keyboard: a field takes it, a list or a button takes it from the fields (and ends the
        --- presentation's hold of the account field as the dialog opens: core/login.lua's askFocus).
        local function focusStop(d, i)
            d.stop = i
            markStop(d)
            if i <= 3 then return d.stops[i]:SetFocus() end
            d.focusOn = nil
            for k = 1, 3 do d.stops[k]:ClearFocus() end
        end

        --- Tab (backwards: Shift+Tab) from the stop that has the keyboard, round.
        local function tabStop(d, backwards)
            local n = #d.stops
            focusStop(d, (d.stop - 1 + (backwards and n - 1 or 1)) % n + 1)
        end

        --- After a press on a control that takes no focus: the field that had the keyboard has it again (the host takes it
        --- from a field at any press).
        local function keepStop(d)
            if d.stops and d.stop <= 3 and d:IsShown() then d.stops[d.stop]:SetFocus() end
        end

        --- A picture button of the layout's (its file, palette, frames and rectangle).
        local function pretty(d, btn, c)
            local l, t, r, b = table.unpack(c.rect)
            X.Pretty(d, btn, c.file, c.palette, c.frames[1], c.frames[2], c.frames[3], l, t, r, b)
        end

        --- A grid's cells in the look's colour and the chosen one's USERPART.EPF frame centred on it (the grids' OnPaint).
        local function drawGrid(f, c, hair, look, chosen)
            for i, cell in ipairs(f.cells) do
                local key = L.CreationCell(look, hair, i)
                cell:SetShown(key ~= "")
                if key ~= "" then cell:SetTexture(key) end
            end
            local key, w, h = TK.Art.Image("USERPART.EPF", 0, "USERPART.PAL")
            f.mark:SetShown(key ~= nil)
            if not key then return end
            f.mark:SetTexture(key)
            f.mark:SetSize(w, h)
            f.mark:ClearAllPoints()
            f.mark:SetPoint("TOPLEFT", f, "TOPLEFT", (chosen - 1) % c.columns * 82 + 41 - math.floor(w / 2),
                -(math.floor((chosen - 1) / c.columns) * 58 + 29 - math.floor(h / 2)))
        end

        --- A colour list's chosen swatch framed: colour 128, and 143 two pixels in (DrawListEntry).
        local function markSwatch(f, chosen)
            local x, y = (chosen - 1) % 4 * 32, math.floor((chosen - 1) / 4) * 32
            for i, inset in ipairs({ 0, 2 }) do
                local m = f.marks[i]
                m:ClearAllPoints()
                m:SetSize(32 - 2 * inset, 32 - 2 * inset)
                m:SetPoint("TOPLEFT", f, "TOPLEFT", x + inset, -(y + inset))
            end
        end

        --- The dialog's look drawn (its createDialog's ShowLook): the chosen gender's and totem's buttons, the totem's
        --- description (string 212 + the totem: SelectTotem 0x0052E770), both grids in the look's colours with the chosen
        --- cells marked, the chosen swatches, and the preview facing the dialog's direction (UpdatePreviewFull).
        local function showLook(d)
            local look, c = d.look, D.CREATE
            X.Chosen(d.male, look.gender == 0)
            X.Chosen(d.female, look.gender == 1)
            for i, btn in ipairs(d.totems) do X.Chosen(btn, look.totem == i) end
            d.totemText:SetText(L.OriginalText(211 + look.totem, ""))
            drawGrid(d.hair, c.hair, true, look, look.hair)
            drawGrid(d.face, c.face, false, look, look.face)
            markSwatch(d.hairColours, look.hairColour)
            markSwatch(d.faceColours, look.faceColour)
            local key = L.CreationPreview(look, d.facing)
            d.preview.figure:SetShown(key ~= "")
            if key ~= "" then d.preview.figure:SetTexture(key) end
        end

        --- A grid (UserHairSelectControlPane, UserFaceSelectControlPane) at its rectangle, black: its cells, the chosen
        --- one's frame. A press chooses the cell under the pointer, and while the button is held each move over the grid
        --- chooses the cell under it; a move off the grid changes nothing (HandlePointerOrMouseEvent 0x005012B0, the face's
        --- 0x00501790: SelectHairAtPoint, 82 x 58 cells, clamped). The look's key follows, and the look is drawn again.
        local function grid(d, f, c, key)
            local l, t, r, b = table.unpack(c.rect)
            X.Rect(f, d, l, t, r, b)
            local black = f:CreateTexture(nil, "BACKGROUND")
            black:SetAllPoints(f)
            black:SetColorTexture(0, 0, 0, 1)
            f.cells = {}
            for i = 1, c.count do
                local cell = f:CreateTexture(nil, "ARTWORK")
                cell:SetSize(82, 58)
                cell:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) % c.columns * 82, -math.floor((i - 1) / c.columns) * 58)
                f.cells[i] = cell
            end
            f.mark = f:CreateTexture(nil, "OVERLAY")
            local function choose()
                local x, y = X.ScreenPoint(TK.Util.CursorRoot())
                if x < l or x >= r or y < t or y >= b then return end
                local col = math.max(0, math.min(c.columns - 1, math.floor((x - l) / 82)))
                local row = math.max(0, math.min(math.floor(c.count / c.columns) - 1, math.floor((y - t) / 58)))
                local cell = row * c.columns + col + 1
                if cell == d.look[key] then return end
                d.look[key] = cell
                showLook(d)
            end
            f:EnableMouse(true)
            f:SetScript("OnMouseDown", function(_, button)
                if button ~= "LeftButton" then return end
                f.tracking = true
                choose()
            end)
            -- each held move, in input order: a move before the release chooses before OnMouseUp ends the tracking
            -- (round 92's final review, P2: a frame's OnUpdate could miss the last cell)
            f:SetScript("OnPressedMove", function() if f.tracking then choose() end end)
            f:SetScript("OnMouseUp", function(_, button)
                if button ~= "LeftButton" then return end
                f.tracking = nil
                keepStop(d)
            end)
            f:SetScript("OnPressCancelled", function() f.tracking = nil end)
        end

        --- A colour list (UserHairColorSelectListPane, UserFaceColorSelectListPane: a ListPane of sixteen 32 x 32 swatches,
        --- four to a row, at its place): each swatch's colour three pixels in; a press on the list gives it the keyboard
        --- (its stop) and a press on a swatch chooses it for the look's key; with the keyboard its arrows step the choice
        --- (f.step: ListPane::OnKeyEvent 0x004F4300, SelectPrevious 0x004F4820 and SelectNext 0x004F4880, stopping at the
        --- ends). The look is drawn again.
        local function swatches(d, f, at, key, hair, stop)
            X.Rect(f, d, at[1], at[2], at[1] + 150, at[2] + 150)
            f.marks = { X.Solid(f, "BORDER", 128), X.Solid(f, "ARTWORK", 143) }
            for i = 1, 16 do
                local t = f:CreateTexture(nil, "OVERLAY")
                t:SetSize(26, 26)
                t:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) % 4 * 32 + 3, -(math.floor((i - 1) / 4) * 32 + 3))
                local red, green, blue = L.CreationSwatch(hair, i)
                t:SetColorTexture(red, green, blue, 1)
            end
            f.step = function(by)
                d.look[key] = math.max(1, math.min(16, d.look[key] + by))
                showLook(d)
            end
            f:EnableMouse(true)
            f:SetScript("OnMouseDown", function(_, button)
                if button ~= "LeftButton" then return end
                focusStop(d, stop)
                local x, y = X.ScreenPoint(TK.Util.CursorRoot())
                local col, row = math.floor((x - at[1]) / 32), math.floor((y - at[2]) / 32)
                if col < 0 or col > 3 or row < 0 or row > 3 then return end
                d.look[key] = row * 4 + col + 1
                showLook(d)
            end)
        end

        --- A New User dialog's three fields at the layout's rectangles in its text colour, the last two masked; Enter is
        --- OK and Escape Cancel after the key's press (byKey), none while its request is out (the dimmer's).
        local function createFields(d, c)
            for k, at in pairs({ account = c.account, password = c.password, repeatBox = c.again }) do
                local l, t, r, b = table.unpack(at)
                X.Edit(d[k], d, l, t, r, b, c.colour)
                d[k]:SetScript("OnEnterPressed", function()
                    if not L.creating then byKey(d.ok, function() L:SubmitCreate() end) end
                end)
                d[k]:SetScript("OnEscapePressed", function()
                    if not L.creating then byKey(d.cancel, function() L:CancelCreate() end) end
                end)
            end
            d.account:SetMaxLetters(L.MAX_ACCOUNT)
            for _, k in ipairs({ "password", "repeatBox" }) do
                d[k]:SetPassword(true)
                d[k]:SetMaxLetters(L.MAX_CREATE_PASSWORD)
            end
        end

        function scripts.Create(d)
            local c = D.CREATE
            createFields(d, c)
            -- the gender (SelectMale 0x0052E850, SelectFemale): the grids' tables follow it, their cells stay
            pretty(d, d.male, c.male)
            pretty(d, d.female, c.female)
            d.male:SetScript("OnClick", function() d.look.gender = 0 showLook(d) end)
            d.female:SetScript("OnClick", function() d.look.gender = 1 showLook(d) end)
            for i, btn in ipairs(d.totems) do
                pretty(d, btn, c.totems[i])
                btn:SetScript("OnClick", function() d.look.totem = i showLook(d) end)
            end
            local l, t, r, b = table.unpack(c.totemText)
            X.Text(d.totemText, d, l, t, r, b, c.colour)
            d.totemText:SetWordWrap(true) -- the StaticTextControlPane wraps at its rectangle's width
            pretty(d, d.ok, c.ok)
            pretty(d, d.cancel, c.cancel)
            pretty(d, d.turn, c.turn)
            d.ok:SetScript("OnClick", function() L:SubmitCreate() end)
            d.cancel:SetScript("OnClick", function() L:CancelCreate() end)
            -- the preview a step round (AdvanceDirection)
            d.turn:SetScript("OnClick", function() d.facing = (d.facing + 1) % 4 showLook(d) end)
            grid(d, d.hair, c.hair, "hair")
            grid(d, d.face, c.face, "face")
            swatches(d, d.hairColours, c.hairColours, "hairColour", true, 4)
            swatches(d, d.faceColours, c.faceColours, "faceColour", false, 5)
            -- the keyboard's stops (above): a field that gains it is the stop, its Tab the dialog's
            d.stops, d.stop = { d.account, d.password, d.repeatBox, d.hairColours, d.faceColours }, 1
            for i = 1, 3 do
                d.stops[i]:HookScript("OnEditFocusGained", function() d.stop = i end)
                d.stops[i]:SetScript("OnTabPressed", function(_, backwards) tabStop(d, backwards == true) end)
            end
            for _, btn in ipairs({ d.male, d.female, d.turn, table.unpack(d.totems) }) do
                btn:HookScript("OnMouseUp", function() keepStop(d) end)
            end
            -- the preview on the dialog's own picture, as ours (core/login.lua, round 36: no black box round the figure)
            l, t, r, b = table.unpack(c.preview)
            X.Rect(d.preview, d, l, t, r, b)
            d.preview.figure = d.preview:CreateTexture(nil, "ARTWORK")
            d.preview.figure:SetAllPoints(d.preview)
            d.ShowLook = function() showLook(d) end
            -- as it opens: the account field's stop (the logic gives it the keyboard), no grid held, the open sound
            d:SetScript("OnShow", function()
                d.stop, d.hair.tracking, d.face.tracking = 1, nil, nil
                TK.Game.Sound.PlayEffect(0x198)
            end)
        end

        -- ----- 5.x's New User dialog (5.33's NewCreateUserDialogPane, its constructor 0x47A0E0; decision
        -- 2026-10-13-5x-new-user-dialog-on-the-one-logic) -----
        -- 5.33's controls over the same look and logic as 7.x's: its row of four shapes (NewUserShapeSelectControlPane,
        -- a head each, 5.33's GetHeadCount) shows the faces 7.5.2's creation offers, and the chosen one is the look's face;
        -- its gender and totem are the look's; its nation (two buttons, the chosen one's description) is the look's
        -- nation. Hair and colours stay the first look's. WIRE: nothing is sent before OK; the shared creation logic
        -- carries the nation to the protocol. 5.33's 0x47BA30 sends selection + 1, while 4a's 0x0052F160 still sends 0.
        -- Changing this input-to-packet path changes what the server sees (L.CreationArgs and L:SubmitCreate).

        local FACES = 12 -- the faces 7.5.2's face grid offers (its 12 cells: L.CreationCell)

        --- The row's four cells (from 5.33's first shape), with centered bounds matching
        --- NewUserShapeSelectControlPane::OnPaint 0x45C9C0; facing and walking frame animate from facing 2 and frame 0
        --- like 5.33's ctor 0x45C7C0 and timer 0x45C8F0. A face set from outside the row (the dialog's open, the
        --- session's first look) is placed as its first cell, as 5.33 selects the first of four from its start.
        local function drawShapes(d)
            local look, c = d.look, D.CREATE.shapes
            if look.face ~= d.rowFace then
                d.rowStart, d.rowFace = math.min(look.face, FACES - 3), look.face
            end
            for i, cell in ipairs(d.shapes.cells) do
                local face = d.rowStart + i - 1
                local key = L.CreationPreview(setmetatable({ face = face }, { __index = look }), d.shapeFacing or 2,
                    d.shapeFrame or 0, true)
                cell.figure:SetShown(key ~= "")
                if key ~= "" then cell.figure:SetTexture(key) end
                cell.capsule:SetShown(face == look.face and cell.capsule.key ~= nil)
            end
        end

        --- 5.x's look drawn (its createDialog's ShowLook): the chosen gender's, nation's and totem's buttons, the nation's
        --- and the totem's descriptions (5.33's strings 208 + the nation and 210 + the totem: 0x47B530, 0x47B5C0), and the
        --- row of shapes.
        local function showShapes(d)
            local look = d.look
            X.Chosen(d.male, look.gender == 0)
            X.Chosen(d.female, look.gender == 1)
            for i, btn in ipairs(d.nations) do X.Chosen(btn, look.nation == i - 1) end
            d.nationText:SetText(L.OriginalText(210 + (look.nation or 0), ""))
            for i, btn in ipairs(d.totems) do X.Chosen(btn, look.totem == i) end
            d.totemText:SetText(L.OriginalText(211 + look.totem, ""))
            drawShapes(d)
        end

        --- An arrow (0x47B310, 0x47B420): the chosen shape one along, the row scrolled by one when it was at the row's end;
        --- nothing past the faces' ends.
        local function stepShape(d, by)
            local face = d.look.face + by
            if face < 1 or face > FACES then return end
            d.look.face, d.rowFace = face, face
            if face < d.rowStart then d.rowStart = face elseif face > d.rowStart + 3 then d.rowStart = face - 3 end
            showShapes(d)
        end

        function scripts.CreateShapes(d)
            local c = D.CREATE
            createFields(d, c)
            pretty(d, d.male, c.male)
            pretty(d, d.female, c.female)
            d.male:SetScript("OnClick", function() d.look.gender = 0 showShapes(d) end)
            d.female:SetScript("OnClick", function() d.look.gender = 1 showShapes(d) end)
            pretty(d, d.left, c.left)
            pretty(d, d.right, c.right)
            d.left:SetScript("OnClick", function() stepShape(d, -1) end)
            d.right:SetScript("OnClick", function() stepShape(d, 1) end)
            for i, btn in ipairs(d.nations) do
                pretty(d, btn, c.nations[i])
                btn:SetScript("OnClick", function() d.look.nation = i - 1 showShapes(d) end)
            end
            for i, btn in ipairs(d.totems) do
                pretty(d, btn, c.totems[i])
                btn:SetScript("OnClick", function() d.look.totem = i showShapes(d) end)
            end
            for _, k in ipairs({ "nationText", "totemText" }) do
                local l, t, r, b = table.unpack(c[k])
                X.Text(d[k], d, l, t, r, b, c.colour)
                d[k]:SetWordWrap(true)
            end
            -- the row: four cells; a left release over a cell chooses it (the cell's pointer handler 0x45C970 acts only on
            -- a left release inside its rectangle; OnControlCommand 8-11)
            local s = c.shapes
            X.Rect(d.shapes, d, s.left, s.top, s.left + 4 * s.width, s.top + s.height)
            d.shapes.cells = {}
            local capsule, cw, ch = S.Image(s.capsule, 0, s.palette)
            local scale = S.GAME_ART or 1
            for i = 1, 4 do
                local cell = CreateFrame("Frame", nil, d.shapes)
                cell:SetSize(s.width, s.height)
                cell:SetPoint("TOPLEFT", d.shapes, "TOPLEFT", (i - 1) * s.width, 0)
                cell.capsule = cell:CreateTexture(nil, "BORDER")
                cell.capsule.key = capsule
                if capsule then
                    cell.capsule:SetTexture(capsule)
                    cell.capsule:SetSize(cw, ch)
                    cell.capsule:SetPoint("CENTER", cell, "CENTER", 0, 0)
                end
                -- 7.5.2's figure art at 5.x's scale (5.33's own figures are half 7.5.2's: skin.lua's GAME_ART)
                cell.figure = cell:CreateTexture(nil, "ARTWORK")
                cell.figure:SetSize(82 * scale, 117 * scale)
                cell.figure:SetPoint("CENTER", cell, "CENTER", 0, 0)
                cell:EnableMouse(true)
                cell:SetScript("OnMouseUp", function(self, button)
                    if button ~= "LeftButton" or not self:IsMouseOver() then return end
                    d.look.face = d.rowStart + i - 1
                    d.rowFace = d.look.face
                    showShapes(d)
                end)
                d.shapes.cells[i] = cell
            end
            X.Image(d, d.ok, c.ok.id, table.unpack(c.ok.rect))
            X.Image(d, d.cancel, c.cancel.id, table.unpack(c.cancel.rect))
            -- OK is the default button (the constructor's SetFocusedControl(20)): its own 1-pixel frame in colour 1, as
            -- 5.33's pictures show it (r89-533 run1 02/03-new-user.png). No Enter frames: the dialog's full background
            -- picture paints over DialogPane's (0x420EC0). Drawing only.
            X.Default(d, d.ok, false)
            d.ok:SetScript("OnClick", function() L:SubmitCreate() end)
            d.cancel:SetScript("OnClick", function() L:CancelCreate() end)
            -- Its keyboard (5.33's NewCreateUserDialogPane 0x0047A0E0, d.stops): the controls built able to take focus, in
            -- their order, are the three fields (TextEdit), the two arrows (PrettyButton, its last argument 1), OK and
            -- Cancel (ImageButton); the gender, nation and totem buttons take none (built with 0). The shape cells are left
            -- out: what their constructor's (0x0045C7C0) last argument means is not in the dumps. Tab and Shift+Tab go
            -- round them (DialogPane_HandleKeyOrTextEvent 0x00420560: 0x00421810, 0x00421780); the account field has the
            -- keyboard first (the constructor's SetHoverControl(1)).
            d.stops, d.stop = { d.account, d.password, d.repeatBox, d.left, d.right, d.ok, d.cancel }, 1
            -- WIRE: what a key presses (P.Key, through byKey's 133 ms): an image button that has the keyboard takes Enter
            -- and Space (its constructor sets consumes-Enter, +0xEC, and ButtonControlPaneFamily 0x00418940 presses it on
            -- the key's down: Sleep(133), then its command as a click's); a picture button takes Space alone (+0xEC is 0),
            -- so its Enter is the default button's, OK's. Changing which control a key presses changes what is sent.
            d.left.press = function() stepShape(d, -1) end
            d.right.press = function() stepShape(d, 1) end
            d.ok.press, d.ok.takesEnter = function() L:SubmitCreate() end, true
            d.cancel.press, d.cancel.takesEnter = function() L:CancelCreate() end, true
            for i = 1, 3 do
                d.stops[i]:HookScript("OnEditFocusGained", function() d.stop = i markStop(d) end)
                d.stops[i]:SetScript("OnTabPressed", function(_, backwards) tabStop(d, backwards == true) end)
            end
            -- a press on a control that takes focus gives it the keyboard (DialogPane's press: SetHoverControl); after one
            -- on a control that takes none, the field keeps it
            for i = 4, 7 do d.stops[i]:HookScript("OnMouseDown", function() focusStop(d, i) end) end
            for _, btn in ipairs({ d.male, d.female, table.unpack(d.nations) }) do
                btn:HookScript("OnMouseUp", function() keepStop(d) end)
            end
            for _, btn in ipairs(d.totems) do btn:HookScript("OnMouseUp", function() keepStop(d) end) end
            d.ShowLook = function() showShapes(d) end
            -- as it opens: the account field's stop, the row placed afresh, and the open sound
            d:SetScript("OnShow", function()
                d.stop = 1
                markStop(d)
                d.rowFace = nil
                d.shapeFrame, d.shapeFacing, d.shapeSteps, d.shapeElapsed = 0, 2, 0, 0
                showShapes(d)
                TK.Game.Sound.PlayEffect(0x198)
            end)
            -- 5.33's ctor 0x45C7C0 starts at frame 0/facing 2; timer callback 0x45C8F0 rearms for 200 ms and turns every
            -- 16 callbacks. Rendering only: this does not mutate d.look, draw random numbers or send packets.
            -- The dialog's OnUpdate belongs to the shared field-focus logic; the preview row owns its own timer.
            d.shapes:SetScript("OnUpdate", function(_, dt)
                d.shapeElapsed = d.shapeElapsed + dt
                if d.shapeElapsed < 0.2 then return end
                d.shapeElapsed = 0
                d.shapeFrame = (d.shapeFrame + 1) % 4
                d.shapeSteps = d.shapeSteps + 1
                if d.shapeSteps == 16 then
                    d.shapeSteps = 0
                    d.shapeFacing = (d.shapeFacing + 1) % 4
                end
                drawShapes(d)
            end)
        end

        -- the alert's one button, "OK" (the label LoginDialogPane::HandlePacketEvent gives it): L:CloseAlert
        function scripts.Alert(a)
            a.ok:SetText("OK")
            a.ok:SetScript("OnClick", function() L:CloseAlert() end)
        end

        -- the connect screen's question: Reconnect (a new connect: core/login.lua's L:Connect, as timer 0 again) or Leave
        -- (the client ends: L:Exit, RequestExit; nothing is connected to close). WIRE: Reconnect passes how it was chosen
        -- (byKey: Enter, else the pointer), so the new session holds the question's closing wait before its connect, as
        -- AlertPane::OnControlCommand 0x004A0580 slides it shut before OnReconnectOrLeave 0x0058B620 starts timer 0 again
        -- (and Enter's press, ActivateDefaultControl 0x0049DE70, before that); changing it moves the reconnect's packets.
        local terminalState
        local function reconnect(byKey)
            terminalState = nil
            L:Connect(byKey == true)
        end
        function scripts.Terminal(t)
            t.alert.reconnect:SetText("Reconnect")
            t.alert.leave:SetText("Leave")
            t.alert.reconnect:SetScript("OnClick", function() reconnect(false) end)
            t.alert.leave:SetScript("OnClick", function() L:Exit() end)
        end

        -- the menu's pointer: a move (the pointer's place changed while it is over the menu itself, not over the dialog
        -- or a window above) and a left release
        function scripts.Track(f)
            if GetMouseFocus() ~= f then return end
            local px, py = TK.Util.CursorRoot()
            if px == lastX and py == lastY then return end
            lastX, lastY = px, py
            follow(px, py)
        end

        function scripts.Release(_, button)
            if button ~= "LeftButton" then return end
            follow(TK.Util.CursorRoot())
            activate()
        end

        local ui = kit.load({ scripts = scripts, elements = kit.elements, parent = screen })
        local f = ui.frame
        page, dialog = f.page, f.page.dialog
        P.frame, P.account, P.password = f, dialog.account, dialog.password
        P.passwordDialog = f.page.password
        P.passwordDialog.dim = f.passwordDim
        L.WirePasswordDialog(P.passwordDialog)
        -- its fields' Enter and Escape after the key's press (byKey) in place of the logic's at once; none while its
        -- request is out (the dimmer's)
        local pw = P.passwordDialog
        for _, k in ipairs({ "account", "current", "new", "again" }) do
            pw[k]:SetScript("OnEnterPressed", function()
                if not pw.dim:IsShown() then byKey(pw.ok, function() L:SubmitPassword() end) end
            end)
            pw[k]:SetScript("OnEscapePressed", function()
                if not pw.dim:IsShown() then byKey(pw.cancel, function() L:CloseChangePassword() end) end
            end)
        end
        P.createDialog = f.page.create

        --- The screen fitted to the window and letterboxed, as the interface's game screen.
        local function fit() X.PlaceAt(page, 0, 0) end
        TK.On("DISPLAY_SIZE_CHANGED", fit)
        TK.On("UI_SCALE_CHANGED", fit)

        function P.CloseDialog()
            dialog.account:ClearFocus()
            dialog.password:ClearFocus()
            dialog:Hide()
        end

        --- The Login entry: the dialog, one at a time (EnsureLoginDialogPane 0x004F8B30), as a new one opens: the last
        --- account, no password, the account field's keyboard.
        function P.OpenDialog()
            if dialog:IsShown() then return end
            dialog.account:SetText(L.account or TK.Machine:Get().recentAccounts[1] or "")
            dialog.password:SetText("")
            dialog:Show()
            -- WIRE (s6-ui-core round 93, head note 30): the new dialog slides open on the main thread (LoginDialogPane
            -- 0x004FA7A0, MainMenuPane.cpp:1257: SlideOpenVertical 0x0049EAC0, 120 ms) inside the press or key that chose
            -- the entry; the session holds it there. Changing it changes when the menu's keep-alive reaches the server.
            L:LoginDialogOpened()
            TK.Game.Sound.PlayEffect(0x198)
            P.Refresh()
            L:FocusField(dialog.account)
        end

        --- OK (WIRE: above): the login's own entry, once enabled and not waiting.
        function P.OK()
            if L.busy or not dialog:IsShown() or not dialog.ok:IsEnabled() then return end
            L:LoginButton()
        end

        function P.Cancel()
            if not L.busy then P.CloseDialog() end
        end

        --- The screen shows (core/login.lua's L:Show): the menu as it opens, entry 1 highlighted, no dialog.
        function P.Show()
            fit()
            if pressing then -- a key's pressed look cut short by the screen going (its command has run)
                pressing.button:SetButtonState("NORMAL")
                pressing = nil
                presser:Hide()
            end
            P.CloseDialog()
            highlight(ITEMS.first)
            lastX, lastY = nil, nil
            P.Refresh()
        end

        --- The logic's state changed (L:UpdateButtons), or a field's text: OK's state, the dimmer while the login waits,
        --- and a lost connection closes the dialog (CloseMainMenuDialogSingletons 0x004F69A0).
        function P.Refresh()
            -- SetEnabled, not Enable/Disable: 5.x's image button draws its disabled wash through it (X.Image), as 5.33's
            -- greyed OK beside an empty password (r89-533 run1 05-login.png). While Enter's press shows on OK (byKey) it
            -- keeps its look, as the original's OK stays pressed through its sleep; the press's end refreshes it (L.busy
            -- refuses a click meanwhile, P.OK).
            if not (pressing and pressing.button == dialog.ok) then
                dialog.ok:SetEnabled(dialog.account:GetText() ~= "" and dialog.password:GetText() ~= "")
            end
            f.dim:SetShown(L.busy == true)
            if L.lost and dialog:IsShown() then P.CloseDialog() end
        end

        --- L:Error's message: a refusal's (or another error's) in the original's alert (AlertPane, HandlePacketEvent
        --- 0x004FAB10: none for an empty message); the progress lines are not shown (the dimmer is the wait).
        function P.Message(text, progress)
            if not progress and text ~= "" then L:Alert(text) end
        end

        --- An alert's window (AlertPane's constructor): the look's standard window sized to the message for its buttons
        --- (X.AlertSize), the message at (24, 24)-(w - 24, h - 56), or to h - 24 without a button; one button at (w - 98,
        --- h - 44)-(w - 24, h - 24); with two, the primary at (w - 184, h - 44)-(w - 110, h - 24) and the secondary there.
        --- The primary (the Enter button) is selected and in the Enter frame. Centred on (cx, cy) of the screen.
        local function drawAlert(a, text, buttons, cx, cy)
            a.text:SetText(text)
            local w, h = X.AlertSize(a.text, #buttons)
            a:SetSize(w, h)
            X.Frame(a, w, h, X.DIALOG_FRAME.file, X.DIALOG_FRAME.palette, X.DIALOG_FRAME.tile)
            X.Text(a.text, a, 24, 24, w - 24, #buttons > 0 and h - 56 or h - 24)
            local left = #buttons == 2 and { w - 184, w - 98 } or { w - 98 }
            for i, b in ipairs(buttons) do
                X.TextButton(a, b, left[i], h - 44, left[i] + 74, h - 24)
                for _, tex in ipairs(b.selectedFrame) do tex:SetShown(i == 1) end
            end
            X.EnterFrame(a, buttons[1])
            a:ClearAllPoints()
            a:SetPoint("TOPLEFT", page, "TOPLEFT", math.floor(cx - w / 2), -math.floor(cy - h / 2))
        end

        --- L:Alert's newest alert (the header): its one text button OK; centred on the dialog it opened over (the login's
        --- or Change Password's, its m_layoutReference), else on the screen; modal (the catcher over the title takes every
        --- other press). An alert that has just opened plays the open sound (DialogPane::AddToLayer: sample 0x198). Its
        --- slide is not drawn.
        function P.ShowAlert(text, opened)
            local over = (dialog:IsShown() and dialog) or (P.passwordDialog:IsShown() and P.passwordDialog) or nil
            local cx, cy = X.CENTRE[1], X.CENTRE[2]
            if over then
                local _, _, _, x, y = over:GetPoint(1)
                cx, cy = x + over:GetWidth() / 2, -y + over:GetHeight() / 2
            end
            drawAlert(page.alert, text, { page.alert.ok }, cx, cy)
            if opened then TK.Game.Sound.PlayEffect(0x198) end
            page.alert:Show()
            f.alertModal:Show()
        end

        function P.HideAlert()
            page.alert:Hide()
            f.alertModal:Hide()
        end

        --- The connect screen in a state (core/login.lua's presentation Terminal; the header): the black screen and its
        --- alert, centred on the screen (the terminal is the screen's size: 7.5.2's the screen, 5.33's 640 x 480), each
        --- alert opening with 0x198; nil hides it.
        function P.Terminal(state)
            local t = page.terminal
            if state == terminalState then return end
            terminalState = state
            t:SetShown(state ~= nil)
            t.alert:SetShown(state == "Connecting" or state == "Failed")
            if not t.alert:IsShown() then return end
            local failed = state == "Failed"
            t.alert.reconnect:SetShown(failed)
            t.alert.leave:SetShown(failed)
            drawAlert(t.alert, failed and L.OriginalText(157, "You are unable to enter the Nexus right now.  Try again soon.")
                or L.OriginalText(156, "Entering the Nexus... It may take a couple of minutes."),
                failed and { t.alert.reconnect, t.alert.leave } or {}, D.SCREEN[1] / 2, D.SCREEN[2] / 2)
            TK.Game.Sound.PlayEffect(0x198)
        end

        --- A key down while no box has the keyboard (core/login.lua's TK.LoginKeyHook; key with its modifiers): true when
        --- the screen took it.
        function P.Key(bare, key)
            -- the connect screen takes every key: its question's Enter is Reconnect, Escape Leave
            if terminalState then
                if terminalState == "Failed" and bare == "ENTER" then
                    reconnect(true)
                elseif terminalState == "Failed" and bare == "ESCAPE" then
                    L:Exit()
                end
                return true
            end
            -- the New User dialog (DialogPane's keys): Enter its OK (5.x: the image button that has the keyboard, if one
            -- does) and Escape its Cancel after the key's press; Space the button that has the keyboard (5.x's stops, its
            -- own press); Tab and Shift+Tab its next and previous stop, and the arrows step the colour list that has the
            -- keyboard (7.x: left and up the swatch before, right and down the one after); none while its request is out
            -- (the dimmer's). WIRE: which control a key presses decides what is sent (CreateShapes' stops).
            local create = P.createDialog
            if create and create:IsShown() then
                if L.creating then return true end
                local stop = create.stops and create.stops[create.stop]
                if bare == "ENTER" and stop and stop.takesEnter then
                    byKey(stop, stop.press)
                elseif bare == "ENTER" then
                    byKey(create.ok, function() L:SubmitCreate() end)
                elseif bare == "ESCAPE" then
                    byKey(create.cancel, function() L:CancelCreate() end)
                elseif bare == "SPACE" and stop and stop.press then
                    byKey(stop, stop.press)
                elseif bare == "TAB" and create.stops then
                    tabStop(create, (key or ""):find("SHIFT%-") ~= nil)
                elseif create.stops and create.stops[create.stop].step then
                    local by = (bare == "LEFT" or bare == "UP") and -1 or (bare == "RIGHT" or bare == "DOWN") and 1
                    if by then create.stops[create.stop].step(by) end
                end
                return true
            end
            -- Change Password with no field focused (core/login.lua's hook lets its keys through): Enter its OK and
            -- Escape its Cancel after the key's press, as its fields' do; none while its request is out (the dimmer's)
            local pw = P.passwordDialog
            if pw and pw:IsShown() then
                if pw.dim:IsShown() then return true end
                if bare == "ENTER" then
                    byKey(pw.ok, function() L:SubmitPassword() end)
                elseif bare == "ESCAPE" then
                    byKey(pw.cancel, function() L:CloseChangePassword() end)
                end
                return true
            end
            if L.busy then return true end -- the dimmer's
            if dialog:IsShown() then
                if bare == "ENTER" then byKey(dialog.ok, P.OK) elseif bare == "ESCAPE" then byKey(dialog.cancel, P.Cancel) end
                return true
            end
            local n = ITEMS.count
            if bare == "UP" or bare == "LEFT" then
                highlight((selected - 1 + n) % n)
            elseif bare == "DOWN" or bare == "RIGHT" then
                highlight((selected + 1) % n)
            elseif bare == "ENTER" then
                activate()
            elseif bare == "ESCAPE" then
                TK.Settings:Open()
            else
                return false
            end
            return true
        end

        -- the version over the picture (OnPaint: "V%d.%d" in font 0 at the pen, the bottom of its 12-pixel line, the
        -- glyphs one pixel lower, as 7.x's S.PenText places a pen's text)
        local v = D.VERSION
        local version = page.version
        S.Text(version, v.colour)
        version:SetWordWrap(false)
        version:SetJustifyH("LEFT")
        version:SetText(v.text)
        version:ClearAllPoints()
        version:SetPoint("TOPLEFT", page, "TOPLEFT", v.x, -(v.y - 12 + 1))
        -- the status line, ours (core/login.lua's contract), under the screen: the connect screen and the alerts say what
        -- the original says
        P.status = L.StatusLine(f)
        return P
    end
end
