-- s6-rules-dialogs: the dialog windows' shared parts. A window draws one dialog of the model (TK.Core.Rules.DialogRules,
-- plan 5.7) from its view, and turns the player's presses, releases and keys into input records for the rules
-- (__tk:DialogPointer, __tk:DialogKey): it sends nothing of its own, so the model stays the only sender. Every control
-- a window shows carries the model's control index; the values the UI keeps (a list's selection, an edit's text) go
-- with each input, as they stand once the UI has handled it (the job's API.md).
--
-- s6-modular-g (interfaces): sizes and places are the dialogs' look (the dialogs component's look, the default in
-- shared/components/dialogs/look/); the kit keeps what a part does: its control index, what its input posts and when.
--
-- Wire: the kit is every dialog's input path. K.Pointer, K.Move, K.Wheel, K.Key, K.Wire, K.Check, K.Edit (and its
-- DialogTyped) and K.Values post what 4a's DialogPane receives (HandlePointerOrMouseEvent 0x0049E240,
-- HandleKeyOrTextEvent 0x0049E6E0): the control and part under the pointer, the button, down or up, the values as they
-- stand after the UI's own handling. The model decides what is sent from them; changing what these post, or when,
-- changes what the server sees.

local W = TK.UI
local H = __tk
local K = {}

--- The dialogs' look (main.lua loads it).
local function look() return TK.GetComponent("dialogs").look end

local SEP = string.char(31)

--- The original's string (its string table, LanguageMan), or the fallback when the packs are not there.
function K.String(id, fallback)
    if id and id > 0 then
        local s = H:OriginalString(id)
        if s and s ~= "" then return s end
    end
    return fallback or ""
end

--- Text from the model for a label: the original's line breaks (CR) as the label's.
function K.Text(s)
    return ((s or ""):gsub("\r\n", "\n"):gsub("\r", "\n"))
end

--- A window for one dialog, width x height with its title, drawn by the look (the default's: an opaque panel, movable). It
--- takes the pointer, so a press on it never reaches the world or the HUD behind it, and it is on the dialogs' strata
--- (main.lua raises the stack from the trade window up). s6-characters (round 46, step 6): the look that draws it gets
--- the renderer's entry and the dialog's class (main.lua's C.drawing, while it builds the window), and the window its
--- class before its parts are placed.
function K.Window(width, height, title)
    local d = TK.GetComponent("dialogs").drawing
    local f
    if d then
        f = d.look.Window(width, height, title, d.entry, d.class)
        f.className = d.class
    else
        f = look().Window(width, height, title)
    end
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f.controls = {}
    f:Hide()
    return f
end

--- The values the window keeps, joined for the bridge; nil for a dialog without fields.
function K.Values(win)
    if not win.Values then return nil end
    local v = win:Values()
    if not v then return nil end
    -- Every value the window keeps, at least one per field: a form's entries are as many as it has, past its two named
    -- fields (review r4, 2).
    local out = {}
    for i = 1, math.max(#v, #(win.view and win.view.fields or {})) do
        local s = v[i]
        if s == nil then s = "" end
        out[i] = (tostring(s):gsub("\n", "\r"))
    end
    return table.concat(out, SEP)
end

--- A press or release of the pointer on one of the window's controls (-1: none of them), on one of its parts (a radio
--- group's option i is i | 0x40; 0 for a control of one part). Returns the bridge's answer ("NotInput" outside a
--- physical press or release: the host posts one record per physical event).
function K.Pointer(win, control, button, down, part)
    if not win.serial then return end
    -- Native TextEditPane::OnMouseEvent (0x00590DE0) follows activation with the clicked text point.
    -- Use the accepted model control, including a native hit proxy; changing this changes the text the server sees.
    local edit = win.controls and win.controls[control]
    if down and (button or "LeftButton") == "LeftButton" and edit and edit.__nativePointerCaret then
        H:NativeEditPointer(edit.__h)
        -- The host focuses the box at its text point in this event, while the rules apply the same press's Activate on
        -- the logic thread: K.SyncFocus holds off until they publish it (the revision moves) or this press's release.
        -- The press barrier's TK.DialogSync refreshed the views just before, and the rules wait at that barrier, so
        -- this is the views' revision.
        win.__pressRevision = H:DialogRevision()
    elseif not down then
        win.__pressRevision = nil -- the rules took the press before this release's barrier
    end
    local x, y = GetCursorPosition()
    return H:DialogPointer(win.serial, control, part or 0, button or "LeftButton", down, K.Values(win), math.floor(x), math.floor(y))
end

--- s6-rules-dialogs (round 35): the part of a press on a list that hits no row (TK.Core.Rules.DialogActions.RowMiss, the
--- same number): the dialog's part of the press runs, its list's does not (4a's ListPane::OnMouseEvent returns false).
K.ROW_MISS = 0x7F

--- Client review 2.40: a press on a list's scroll bar (its thumb, arrows or track), the list control's but no row's.
--- Wire: 4a's ScrollableControlPane gives it to its ScrollPane, outside the rows (ScrollPane.cpp:955), so no row is
--- activated (ListPane.cpp:260: a double activates only a row hit) and the user list queries no hunter
--- (UserListDialogPane.cpp:822); the board and mail lists still read their end after it (3B 02). The model takes this
--- part as such (DialogActions.BarHit, Dialog.Click). Posting a bar press as a row's sends the selected row's answer (3A)
--- or a hunter's query (85).
K.BAR_HIT = 0x7E

--- A pointer move while a press on one of the window's controls is held (round 8): 4a hands it to the pressed control,
--- with the values after it (a list's scroll bar dragged to its end asks for older rows).
function K.Move(win, control)
    if not win.serial then return end
    local x, y = GetCursorPosition()
    H:DialogMove(win.serial, control, K.Values(win), math.floor(x), math.floor(y))
end

--- The wheel over one of the window's controls (a list), with the values after the scroll.
function K.Wheel(win, control)
    if not win.serial then return end
    local x, y = GetCursorPosition()
    H:DialogWheel(win.serial, control, K.Values(win), math.floor(x), math.floor(y))
end

--- Client review 2.44 (Astra's pass 8): the list whose scroll bar holds the left press (K.heldBar), or nil to end it;
--- the held list takes the wheel meanwhile (Frame:SetWheelCapture on its area). WIRE: 4a's ScrollPane has the input's
--- capture from that press to its release (ScrollPane.cpp:125, :134), and EventDispatcher hands the capture's source,
--- the holding DialogPane, every pointer event, the wheel too, even under a newer dialog (EventDispatcher.cpp:258,
--- DialogPane.cpp:388): a covering NPC list turned instead and the mail list never asked for older rows (3B 02).
local function holdBar(list)
    local held = K.heldBar
    if held == list then return end
    if held then held.sf:SetWheelCapture(false) end
    K.heldBar = list
    if list then list.sf:SetWheelCapture(true) end
end

--- Client review 2.44 (Astra's pass 7): whether a dialog list's scroll bar holds a left press (K.heldBar, set by the
--- thumb's or bar's accepted press, cleared by its release: list:ThumbRelease). WIRE: 4a's ScrollPane then has the
--- capture and declines every key (ScrollPane.cpp:125, :178; EventDispatcher.cpp:279), so the dialogs' key hook
--- (main.lua TK.DialogKeyHook) takes the key for nothing: an arrow there moved an NPC list's answer before the model
--- declined the key (DialogRules' ModalInput), and the next 3A named it. Changing it changes what the server gets.
function K.BarHeld()
    local held = K.heldBar
    if held and not held.sf:IsVisible() then holdBar(nil); held = nil end -- its window went with it
    return held ~= nil
end

--- A key-down for the window's dialog, with its values.
function K.Key(win, key)
    if not win.serial then return end
    return H:DialogKey(key, win.serial, K.Values(win))
end

--- A control's optional geometric hit test, evaluated at this input's own position (never cached).
--- Wire: PointInRect 0x004B7E80 excludes right/bottom edges; a look can keep those bounds when the host's rectangle
--- raycast includes them. Changing the selected control changes the values/command the server receives later.
local function hitControl(frame, index)
    if frame.__dialogHitTest and not frame.__dialogHitTest(frame) then return -1 end
    return index or frame.__dialogControl
end

--- The control of win at (x, y) in UIParent units, as DialogPane::HitTestControls (0x0049FB10) finds it: the
--- highest-indexed control whose rectangle holds the point, or -1; and the scroll bar frame it hit, if any.
--- Client review 2.29. Wire: 4a's PointInRect (0x004B7E80) takes the left and top edges and leaves the right and bottom
--- ones; UIParent's y runs up, so the top edge is b + h (taken) and the bottom b (left). Changing the edges changes which
--- control a press on one picks.
--- Client review 2.44 (Astra's passes 6 and 7). WIRE: a list's control is 4a's ListPane with its scroll bar (ScrollPane,
--- ScrollPane.cpp:955), so the bar (the kit's thumb or track, 7.x's 4a bar right of the rows, or 5.33's own bar:
--- list.nativeBar) is the list's control too; the list's frame ends at its bar. Changing it changes which control a
--- press there reaches, and whether its list pages (3B 02).
local function within(f, x, y)
    local l, b, w, h = TK.Util.RootRect(f)
    return l and x >= l and x < l + w and y > b and y <= b + h
end
local function hitAt(win, x, y)
    local function holds(f) return within(f, x, y) end
    local best, bar = -1, nil
    for index, f in pairs(win.controls or {}) do
        if index > best and f:IsVisible() then
            local hit
            if f.list then
                local native = f.list.nativeBar and f.list.nativeBar.frame
                if native and native:IsVisible() and holds(native) then hit = native
                elseif f.thumb and f.thumb:IsVisible() and holds(f.thumb) then hit = f.thumb
                elseif f.track and f.track:IsVisible() and holds(f.track) then hit = f.track end
            end
            if hit or holds(f) then best, bar = index, hit end
        end
    end
    return best, bar
end

--- Client review 2.44 (Astra's passes 9 to 11): a wheel turn a dialog got outside its place goes to the side panel's
--- shown page whose bounds hold the pointer (7.x's side panel: its WheelAt), or nowhere. WIRE: 4a's DialogPane
--- forwards an event outside its bounds to the GeneralPurposePanel's active child pane by that pane's bounds
--- (DialogPane.cpp:404, :427-430; its tab strip takes no wheel), so a turn there while a dialog's bar holds the press
--- still moves the spell list, its blank band too (SpellInventoryPane.cpp:679), whose row a later click casts (0F);
--- dropping it changes that slot.
local function sidePaneWheel(delta)
    local side = TK.GetComponent("7x.side")
    if not (side and side.WheelAt) then return end
    local x, y = TK.Util.CursorRoot()
    side:WheelAt(x, y, delta)
end

--- Client review 2.44 (Astra's pass 9): the window's held press ended with no release of its own (the host swallowed it,
--- UIHost.MouseUp: 7.x's item box shown): a drawn drag stops and the held bar lets go (5.33's bar's repeat, the kit's
--- timer, the hold and its wheel capture: list:ThumbRelease) with nothing posted. WIRE: the model's capture ends with the
--- physical release (DialogRules, as 4a's at ScrollPane.cpp:134); posting a release here would send a second input
--- record, and keeping the hold kept taking the window's keys (an arrow lost, so the next 3B 03 named the old row).
function K.CancelPress(win)
    local bar = win.__pressedBar
    win.__pressedBar = nil
    local stop = bar and bar:GetScript("OnDragStop")
    if stop then stop(bar) end
    local held = K.heldBar
    if held and held.sf.__dialogWin == win and not (held.nativeBar and held.nativeBar:Cancel()) then held:ThumbRelease() end
end

--- Client review 2.42 (Astra's passes 5 and 15). WIRE: 4a's HitTestPart gives 10 for a point on no part of a radio
--- group (its gap, RadioGroupControlPane 0x00496270) or of a slider (off its parts 13-17, SliderControlPane
--- 0x00496800), and DialogPane::HandlePointerOrMouseEvent (0x0049E240, DialogPane.cpp:318-331) takes such a press as
--- its background drag: no control is focused or tracked, and a release there commands nothing (:376-386). A frame
--- whose part 10 means that (frame.__noPart: the user list's sort, the music sliders) posts it as outside the
--- dialog's controls (-1); every other part keeps its number (the fitting room's entries count from 1). Tracking the
--- gap let the sort's radio take its release and reorder the rows a row press asks 85 for; changing it changes what
--- the server sees.
K.NO_PART = 10
local function onPart(frame, index, part)
    if part == K.NO_PART and frame and frame.__noPart then return -1, 0 end
    return index, part
end

--- The control of this window under the pointer and its part, or -1. While a slide's shield holds a press, at the
--- shield's moved point (win.__pointAt; dialogkit.lua X.SlideOpen), as 4a hit-tests the queued release against the
--- window at its place (client review 2.44).
--- Client review 2.42 (Astra's pass 5). WIRE: at the shield's point a control with options (f.PartAt: the user list's
--- sort radio) gives the option there, as RadioGroupControlPane::HitTestPart (0x00496270) does for 4a's release; the
--- option the radio takes orders the rows a row press asks 85 for, so part 0 there changed what the server sees.
local function controlUnderPointer(win)
    if win.__pointAt then
        local x, y = win.__pointAt()
        local best = hitAt(win, x, y)
        local c = win.controls[best]
        return onPart(c, best, c and c.PartAt and c:PartAt(x, y) or 0)
    end
    local f = GetMouseFocus()
    while f do
        if f.__dialogWin == win and f.__dialogControl then
            -- 4a DialogPane::HandlePointerOrMouseEvent 0x0049E240 hit-tests Up afresh after the control releases.
            -- Reusing a slider's pressed part can refresh enables and expose extra shared C12 draws to the wire path.
            local part = f.__dialogPart
            return onPart(f, hitControl(f), (type(part) == "function" and part(false) or part) or 0)
        end
        f = f.__dialogParent
    end
    return -1, 0
end

--- s6-characters (round 46, step 6; TK.Dialogs.Control): marks frame as the window's control index (and part) for the
--- release's lookup (controlUnderPointer), as K.Wire marks a window's own, without wiring its presses: a frame outside the
--- window whose presses the caller posts (an interface's own button for one of a dialog's controls; the parcel pane's
--- buttons have TK.Game.Parcels' own registry, step 4b). Wire: it decides which control a release over it reaches, as
--- 4a's dialog gives a release to the control under it (DialogPane::HitTestControls 0x0049FB10); changing it changes
--- what the model does with the release, so what the server receives.
--- hitTest(frame), when supplied, limits the host's pointer rectangle for both presses and the release lookup above.
--- It matches 4a's PointInRect 0x004B7E80 / HitTestControls 0x0049FB10; changing it changes what the server sees.
function K.Control(frame, win, index, part, hitTest)
    frame.__dialogWin, frame.__dialogControl, frame.__dialogPart = win, index, part
    frame.__dialogHitTest = hitTest
    return frame
end

--- Makes frame the window's control index (and part: a radio group's option): its presses and releases go to the
--- model (a release to the control and part under the pointer then, as DialogPane matches them). before(button) may
--- change the UI's values first. A callable part takes true for the pressed part, false for a fresh release hit test.
function K.Wire(win, frame, index, before, part)
    frame.__dialogWin = win
    frame.__dialogControl = index
    frame.__dialogPart = part
    -- s6-ui-core (round 127): the window's wired frames, so the gate's driver names a radio's options (gatecontrols.lua)
    win.wired = win.wired or {}
    win.wired[#win.wired + 1] = frame
    frame:HookScript("OnMouseDown", function(_, button)
        if before then before(button) end
        -- r66: a shared original slider reports its pressed part after its own handler (4a SliderControlPane
        -- 0x004974B0). Constant radio parts keep their existing route; changing this changes the wire input path.
        local pressedPart = type(part) == "function" and part(true) or part
        -- s6-characters r51: the same optional bounds as the release (0x0049FB10 / 0x004B7E80); changing the hit changes
        -- which control the model tracks and therefore which reply the server receives.
        -- 2.42: a press on no part of a radio or a slider is the dialog's background (onPart, above)
        local target, targetPart = onPart(frame, hitControl(frame, index), pressedPart)
        K.Pointer(win, target, button, true, targetPart)
    end)
    frame:HookScript("OnMouseUp", function(_, button)
        local over, overPart = controlUnderPointer(win)
        K.Pointer(win, over, button, false, overPart)
    end)
    return frame
end

--- s6-modular-g (Astra's review of round 12, 3): whether c is a K.Check box, whose own state is a boolean (a host check
--- button keeps its checked texture under the same name, frame.lua's SetCheckedTexture).
local function kitCheck(c) return c ~= nil and type(c.__checked) == "boolean" end

--- Client review 2.28: a pickOnRelease list's left release takes the row under it (x, y in UIParent units), before the
--- release is posted, so the release's values carry it. Wire: RankingEventListPane::HandlePointerOrMouseEvent
--- (0x0045B460, RankingEventScrollPane.cpp:736-752) picks nothing on the press and hit-tests the release (HitTestRow):
--- a row other than the selected one is selected and its page asked for (7D 02); no row leaves the selection. Changing
--- it changes which category's 7D 02 the server gets.
local function pickOnRelease(list, x, y)
    local row = list:HitRow(x, y)
    if not row then return end
    list:Pick(row, IsShiftKeyDown(), IsControlKeyDown())
    if list.onSelect then list.onSelect(row) end
end

--- s6-rules-dialogs (round 34; s6-modular-g round 11's note): a press or release on a window that is sliding open, given
--- to the control that is at its point once the window is at its place. A look that animates the slide catches the
--- presses over the window's place and calls this from each one's own event (the host posts one record per physical
--- event, plan 5.9), with x, y the point moved onto the window's frames as they are drawn now (UIParent units: the
--- press's point plus the slide's current offset), so it hits what 4a hits at the window's place.
--- Wire: 4a handles no input while DialogPane::SlideOpenVertical (0x0049EAC0) runs; the press waits in the message
--- queue and is then hit-tested against the window at its place: DialogPane::HitTestControls (0x0049FB10) gives the
--- highest-indexed control whose rectangle holds the point (our controls' indexes are 4a's), and a list picks the row
--- its own press would (list:RowAt, ListPane::HitTestItem's clamp), or a press that hits none is the dialog's alone
--- (K.ROW_MISS). The record waits too: the model's own stall for the slide (Dialog.Slide) holds it until then. Changing
--- which control or row this picks changes what the client sends.
--- Client review 2.42 (Astra's pass 5): a control with options (f.PartAt: the user list's sort radio, which slides
--- open) gives the option at the point, on the press and on the release (RadioGroupControlPane::HitTestPart 0x00496270:
--- 0x40 + i, or 10 off both). Part 0 there made a click on the active option turn the sort over, which changes the
--- name a row press asks 85 for.
--- s6-modular-g (Astra's review of round 12, 3): a release over the control that had the press is then that control's
--- click, as the host gives it after the release's own scripts (UIHost.MouseUp): a check box toggles (UICheckButton's
--- BeforeClick; K.Check's own state in its OnClick, which posts that release itself), so the dialog's OK reads the box as
--- the player set it during the slide (PartySearchEditPane::OnControlCommand 0x0059E3D0 sends 84 from it). Dropping the
--- click changes the reply the server gets.
--- s6-modular-g (round 13 fix, Astra): double is the host's double-press flag (OnMouseDown's third argument). Wire: 4a's
--- HandlePointerOrMouseEvent (0x0049E240) gives a double-click's second press (event 2) to the control under it but
--- tracks nothing (DialogPane.cpp:396-402), so its release commands nothing (:376-386): here such a press is posted and
--- its release is posted, but it makes no click, for any control (a check box, a button, the user list's sort). A click
--- there toggled the hunters box twice, so OK sent 84 00 where 4a sends 84 01; changing it changes the reply.
function K.PressAt(win, x, y, button, down, double)
    local left = button == "LeftButton"
    if not (win.serial and win:IsShown()) then
        -- client review 2.44 (Astra's pass 7, P2): a held bar's drawn drag ends with its window
        if not down and left and win.__pressedBar then
            local held = win.__pressedBar
            local stop = held:GetScript("OnDragStop")
            win.__pressedBar = nil
            if stop then stop(held) end
        end
        return
    end
    -- Client review 2.44 (Astra's passes 6 and 7). WIRE: a press on a list's scroll bar (hitAt) is the bar's press (its
    -- own OnMouseDown, below: 4a's thumb or track press, then 3B 02 at a board's or the mail list's end).
    local best, bar = hitAt(win, x, y)
    local f = win.controls[best]
    local list = f and f.list
    local part
    -- s6-input (round 43; Astra's self-review): the pressed control and row are the left press's, the one 4a's DialogPane
    -- tracks (HandlePointerOrMouseEvent 0x0049E240: type 1 only); a right press or release between keeps them, so the
    -- left release still reaches the tracking list (its tick's stop) and the held moves still go to it.
    if down and left then win.__pressedRow, win.__pressedBar = nil, nil end
    if down and bar then
        -- 2.44: the bar's own press, at the shield's point (K.List's pointer and 5.33's Bar:Pointer read win.__pointAt).
        -- An ordinary left press holds it (4a's capture): the held moves (K.PressedMoveAt) and the release (below) are
        -- the bar's, and a thumb that drags its drawn list (K.List) drags it from here, as its own drag would. 5.33's bar
        -- passes a double's second press on (scrollbar.lua): here it is the list's bar press alone, which the model
        -- ignores (2.40: Dialog.Click).
        local native = list.nativeBar and bar == list.nativeBar.frame
        if native and double then return K.Pointer(win, best, button, true, K.BAR_HIT) end
        bar:GetScript("OnMouseDown")(bar, button, double)
        if left and not double then
            win.__pressedBar = bar
            local drag = bar:GetScript("OnDragStart")
            if drag then drag(bar) end
        end
        return
    end
    if not down and left and win.__pressedBar then
        -- 2.44: the held bar's release, by its own OnMouseUp (4a's ResetScrollState, then the release to the control
        -- under the shield's point: controlUnderPointer), after its drawn drag's stop
        local held = win.__pressedBar
        win.__pressedAt, win.__pressedRow, win.__pressedBar = nil, nil, nil
        local stop = held:GetScript("OnDragStop")
        if stop then stop(held) end
        held:GetScript("OnMouseUp")(held, button)
        return
    end
    if down and list then
        local row = list:RowAt(y, x)
        if left then list:FollowPress(row ~= nil and not double) end -- 2.41: an ordinary press follows
        if row and button == "LeftButton" and not list.pickOnRelease then -- 2.28: such a list's row is the release's
            list:Pick(row, IsShiftKeyDown(), IsControlKeyDown())
            if list.onSelect then list.onSelect(row) end
            -- s6-input (round 42): K.List's rows, below. Round 43: the row the shield's held moves go to (K.PressedMoveAt).
            if not double and not list.own then
                H:DialogListTracks()
                win.__pressedRow = list.rows[row]
            end
        end
        if not row then part = K.ROW_MISS end -- round 35: a press that hits no row is the dialog's alone (below)
    end
    if f and f.PartAt and not part then part = f:PartAt(x, y) end -- 2.42: a radio's option at the point (above)
    best, part = onPart(f, best, part) -- 2.42: a radio's gap is the dialog's background press
    if best == -1 then f = nil end
    if down then
        -- only an ordinary press is tracked (event 1); a double's second press (event 2) leaves none for its release
        if left then win.__pressedAt = not double and best or nil end
        if kitCheck(f) then f.__tracked = button == "LeftButton" and not double end -- K.Check's press tracks it
        return K.Pointer(win, best, button, true, part)
    end
    local pressed = left and win.controls[win.__pressedAt or -1] or nil
    -- 2.41 (Astra's pass 13): a tracked row press's release follows at the shield's point first (list:FollowRelease)
    local tracked = left and win.__pressedRow and pressed and pressed.list
    if left then win.__pressedAt, win.__pressedRow = nil, nil end
    if tracked then tracked:FollowRelease() end
    -- Client review 2.28 (pickOnRelease, above): the pressed list's release over itself takes its row first.
    if pressed and pressed == f and f.list and f.list.pickOnRelease then pickOnRelease(f.list, x, y) end
    -- s6-input (round 43): the left release reached the pressed list, its window still open (above): its case 3 (below).
    if pressed and pressed.list and not pressed.list.own then H:DialogListReleased() end
    local click = pressed == f and left and f and f.Click
    if kitCheck(pressed) and not click then pressed.__tracked = false end
    if click and kitCheck(f) then
        f:Click(button)
        return
    end
    local answer = K.Pointer(win, best, button, false, part)
    if click then f:Click(button) end
    return answer
end

--- s6-input (round 43; Astra's review of round 42): a move while a press K.PressAt passed on is held (a look's slide shield
--- keeps the press, a hardware move or EventMan's auto-scroll tick): the pressed row's own OnPressedMove, as if the row
--- held the press. Wire: in 4a the press waits for the slide's end and then the list tracks it, so every move after it,
--- the tick's every 20 ms included, reaches the list (ListPane::OnMouseEvent 0x004F4190 case 0: its step, then the
--- article or mail list's 3B 02 at its end). Not forwarding them leaves a list pressed during the slide unscrolled and
--- unpaged, which changes what the server sees.
function K.PressedMoveAt(win)
    -- client review 2.44: or the held scroll bar's (K.PressAt): its moves go to the list, which pages at its end
    local row = win.__pressedRow or win.__pressedBar
    local move = row and row:GetScript("OnPressedMove")
    if move then move(row) end
end

-- ----- s6-characters (round 46, step 6 of the interface separation): the input routing of a look that draws the
-- original's windows, moved here from 7.x's look (interfaces/7x/dialogs/init.lua's X.List, X.Blocker and X.SlideOpen,
-- then step 5's shared/original/dialogkit.lua) unchanged, with their wire comments. The look still places and
-- draws. -----

--- A list (K.List) drawn as one of 4a's ListPanes: its rows width wide (the whole width left of its bar) and rowHeight
--- high (TK.Dialogs.ListRows).
--- Input routing (wire): the rows take the whole width left of the bar, so a press anywhere across the list is the row's
--- at its height, as ListPane::HitTestItem (0x004F4480) clamps a press into the cells (Astra's review of round 10); their
--- height is the list's own, so the pointer picks the row 4a's would. Changing either changes which row a press picks,
--- and the reply that sends it. The article and mail lists also page by their rows' height and their rectangle's (7.x's
--- boards.lua, L.BoardList: when older rows are asked for).
function K.ListRows(list, width, rowHeight)
    list:SetWidth(width)
    list:SetRowHeight(rowHeight)
end

--- A frame (a child of parent, over what was made before it) that takes the pointer and does nothing with it; the look
--- places it over a rectangle of the window (TK.Dialogs.Blocker). It is a control of 4a's that is hit but acts on no
--- press (a StaticTextControlPane: DialogPane::HitTestControls 0x0049FB10 walks the controls from the last, and only
--- SetIgnoreHitTesting takes one out), so a press there does not reach a control under it. Input routing (wire): it keeps
--- a press from a button 4a's would not give it to (the small TextDialog's stacked buttons), so changing it changes what a
--- press sends.
function K.Blocker(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:EnableMouse(true)
    return f
end

--- The shield of a window sliding open (a frame over the window's place while the look's slide draws it): its presses,
--- releases and held moves go to the window (TK.Dialogs.SlideShield). raised() is how far above its place the slide
--- draws the window now (UIParent units); held(on) tells the look a press is held or let go (the look keeps the shield
--- until its release).
--- Input routing (wire): 4a handles a press made during its slide (DialogPane::SlideOpenVertical 0x0049EAC0) after the
--- slide, against the window at its place. The model's wait is that delay; so here a press on the window's place while
--- the picture still slides goes at once, in its own physical event, to the window's control there, its release too:
--- K.PressAt (DialogPane::HitTestControls 0x0049FB10, a list's row by ListPane::HitTestItem's clamp, a press on no row
--- the dialog's alone, a release over the pressed control its click: a check box toggles; none after a double-click's
--- second press, which 4a does not track: HandlePointerOrMouseEvent 0x0049E240, so its release clicks nothing; dropping
--- it toggled a check box twice), given the point moved onto the frames as the slide draws them now; no hit test of the
--- look's own. The moves while the shield holds a press passed on to a list's row, EventMan's auto-scroll tick's every
--- 20 ms included, go to that row as 4a's go to the list that tracks the press once the slide is over
--- (ListPane::OnMouseEvent 0x004F4190 case 0: its step, then 3B 02 at a board's or the mail list's end):
--- K.PressedMoveAt; dropping it leaves such a list unscrolled and unpaged. Changing this changes which control a press
--- reaches or when, so what the client sends and when.
function K.SlideShield(shield, win, raised, held)
    local function pass(down, button, double)
        local px, py = TK.Util.CursorRoot()
        K.PressAt(win, px, py + raised(), button, down, double)
    end
    shield:EnableMouse(true)
    shield:SetScript("OnMouseDown", function(_, button, double)
        held(true)
        pass(true, button, double)
    end)
    shield:SetScript("OnMouseUp", function(_, button)
        pass(false, button)
        held(false)
    end)
    shield:SetScript("OnPressedMove", function() K.PressedMoveAt(win) end)
end

--- A check box of the model's control index (CheckBoxControlPane): it toggles on its own release over it
--- (ControlPane.cpp:2063-2071), and that release goes to the model with the value after the toggle. Only a release the
--- dialog hands it toggles it: one after a tracked press; a double-click's second press (event 2) tracks none, so its
--- release does nothing (DialogPane.cpp:367, :388; review r5, 3). The box keeps its own state (the host's click toggle
--- is undone); a left release over it is posted from OnClick, after the host's click, any other from OnMouseUp.
function K.Check(win, index, label)
    local c = W.Check(win, label)
    win.controls[index] = c
    c.__dialogWin, c.__dialogControl = win, index
    c.__checked = false
    function c:SetValue(on)
        self.__checked = on and true or false
        self:SetChecked(self.__checked)
    end
    c:HookScript("OnMouseDown", function(_, button, double)
        K.Pointer(win, index, button, true)
        c.__tracked = button == "LeftButton" and not double
    end)
    c:HookScript("OnMouseUp", function(_, button)
        local over, part = controlUnderPointer(win)
        if button ~= "LeftButton" or over ~= index then
            c.__tracked = false
            K.Pointer(win, over, button, false, part)
        end
    end)
    c:HookScript("OnClick", function(_, button)
        if button ~= "LeftButton" then return end
        if c.__tracked then c.__checked = not c.__checked end
        c.__tracked = false
        c:SetChecked(c.__checked)
        K.Pointer(win, index, button, false)
    end)
    return c
end

--- A button of the model's control index.
function K.Button(win, index, text, width, height)
    local b = W.Button(win, text, width or 90, height or 24)
    win.controls[index] = b
    return K.Wire(win, b, index)
end

--- Buttons of the model's control indexes, spec { {index, text}, ... }, each width wide, in the spec's order (the look
--- places them: the boards' and the shops' dialogs as a row from the bottom right).
function K.Buttons(win, spec, width)
    local buttons = {}
    for i, s in ipairs(spec) do buttons[i] = K.Button(win, s[1], s[2], width) end
    return buttons
end

--- The portrait (ObjectImageControlPane 0x005205C0) at the window's top left, when the model gives one (picture): 4a's
--- 74 x 108 pane, painted by s6-characters from the packet's tagged look (status: a character composed facing south, a
--- creature's standing frame, an item's glyph, centred on black; round 21). The model has already applied 4a's tag
--- override (portrait kind 2 makes it an item). Returns how far right the window's text starts (0 without a picture)
--- and how tall the portrait is. Its size and place are the look's (L.Portrait, or the window's own, win.portraitSpec:
--- s6-modular-g, a look whose dialogs each place it, as 7.x's).
function K.ShowPicture(win, picture, status)
    local P = win.portraitSpec or look().Portrait
    local box = win.portrait
    if not box then
        box = CreateFrame("Frame", nil, win)
        box:SetSize(P.width, P.height)
        box:SetPoint("TOPLEFT", win, "TOPLEFT", P.left, P.top)
        local bg = box:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(box)
        bg:SetColorTexture(0, 0, 0, 1)
        box.bg = bg
        box.tex = box:CreateTexture(nil, "ARTWORK")
        box.tex:SetAllPoints(box)
        win.portrait = box
    end
    box.tex:Hide()
    if type(picture) ~= "table" then
        box:Hide()
        return 0, 0
    end
    -- s6-modular-g: a look that places it per dialog may move it between updates (7.x's text and small windows)
    if win.portraitSpec then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", win, "TOPLEFT", P.left, P.top)
    end
    if P.black == false then box.bg:Hide() else box.bg:Show() end
    box:Show()
    -- s6-modular-g (round 12, s6-characters round 38's call): a look without the black (7.x's: 4a's pane is mode 1,
    -- colour 0 see-through) asks for the picture clear wherever the figure does not draw.
    -- s6-interface-5x-b (round 6): a look whose screen draws the base set's art at a scale (P.scale: 5.x's S.GAME_ART,
    -- 5.33's art being half 7.5.2's) asks for the picture that much larger in the base set's pixels, shown in its box.
    local s = P.scale or 1
    local key = status and H:GetObjectImage(status, math.floor(P.width / s + 0.5), math.floor(P.height / s + 0.5), P.black == false) or ""
    box.key = key
    if key ~= "" then
        box.tex:SetTexture(key)
        box.tex:Show()
    end
    return P.textX, P.height
end

--- A read-only text block (word-wrapped).
function K.Block(parent, size, justify)
    local fs = W.Label(parent, "", size or 13, W.white, justify or "LEFT")
    fs:SetWordWrap(true)
    fs:SetJustifyV("TOP")
    return fs
end

--- The one character a box's change added ("" for any other change: a deletion, a paste).
function K.Added(before, now)
    if #now ~= #before + 1 then return "" end
    for i = 1, #now do
        if now:sub(i, i) ~= before:sub(i, i) then
            return now:sub(i, i + #now - #before - 1)
        end
    end
    return ""
end

--- An edit box of the model's control index: typing (the key that typed it, as the host saw it: a keypad digit stays
--- the keypad's, with its modifiers), Enter, Escape and Tab reach the model with the text after them.
--- Wire: the box selects its text when it takes the focus (the host's default), as 4a's TextEditControlPane::Activate
--- (0x00498ED0) does with SetSelectionRange(0, 0x7fff), so a key typed into a box the dialog's focus or Tab has just
--- given the keyboard replaces what it holds (a reply's or a mail field's text, the clan bank's "1") and the text that
--- goes with the key is the new one alone. Changing it changes what the server sees. The trade's money field is the one
--- exception (exchange.lua). Native pointer activation then places the caret at the text point, as TextEditPane's
--- OnMouseEvent (0x00590DE0) does; K.Pointer requests that step in the same event. Modern/plugin edits keep their policy.
function K.Edit(win, index, width, height, multiline)
    local e = W.EditBox(win, width, height)
    local drawing = TK.GetComponent("dialogs").drawing
    -- The selected drawing declares the existing pointer rule; a distinct With(skin) capsule alone is not native.
    -- Keep shared-default fallbacks on their activation policy, even when the selected look has native entries.
    e.__nativePointerCaret = drawing ~= nil and drawing.look ~= TK.Dialogs.DefaultLook()
        and drawing.look.NativePointerCaret == true
    if multiline then e:SetMultiLine(true) end
    win.controls[index] = e
    K.Wire(win, e, index)
    e.__before = ""
    e:SetScript("OnTextChanged", function(self, userInput)
        local before, now = self.__before or "", self:GetText()
        self.__before = now
        -- s6-ui-core (review r19 finding 1): with the character this change added, so a live key takes its own values.
        if userInput and win.serial then H:DialogTyped(win.serial, K.Values(win), K.Added(before, now)) end
    end)
    e:SetScript("OnEnterPressed", function() K.Key(win, "ENTER") end)
    e:SetScript("OnEscapePressed", function() K.Key(win, "ESCAPE") end)
    e:SetScript("OnTabPressed", function() K.Key(win, "TAB") end)
    return e
end

--- Sets an edit's text from the model (no key goes back for it).
function K.SetEdit(e, text)
    text = K.Text(text)
    if e:GetText() ~= text then
        e:SetText(text)
        -- Round 36 (wire): the caret after the text, where 4a's InsertText and SetText leave it (TextEditPane::InsertTextRange
        -- 0x0058FC30 moves the selection to the inserted text's end), so what the player types next follows it.
        e:SetCursorPosition(#text)
    end
    e.__before = text
end

--- The client review's 2.16: the text the model keeps for each box whose typed text 4a's control could not hold
--- (TK.Core.Rules.Dialog.TextBox: its width, lines and characters), back in the box, as 4a's control deletes what does
--- not fit (TextEditPane::EnforceMaxLength 0x00591180, EnforceMaxLines 0x00591200). Wire: the next key types into what
--- the original's box holds, so the text the dialog posts is the original's; changing it changes what the server gets.
function K.FitBoxes(win, view)
    local boxes = view.contents and view.contents.boxes
    if not boxes then return end
    for _, box in ipairs(boxes) do
        local e = win.controls and win.controls[box[1]]
        if e and e.SetText then
            local text = K.Text(box[2])
            -- Wire (Astra's review of 57264cc2bb): not K.SetEdit's caret at the end. 4a's limits delete only what does
            -- not fit and clamp the selection's ends to what is left (TextEditPane.cpp:1455-1456, :1470-1471), so the
            -- caret stays where the key left it, as TMP's text setter keeps it (clamped to the new length). At the end,
            -- a key typed inside a full box would go after its text: 4a's 5612 from 1234, Home, 5, 6 would be 5123.
            if e:GetText() ~= text then e:SetText(text) end
            e.__before = text
        end
    end
end

--- A list of rows (single choice, or several with multi): control index, rows drawn by render(row, item, i).
--- Its selection is the UI's; a press on a row selects it before the press goes to the model. width x height is the
--- look's; the rows' height is the list's (20 unless the look sets the original's with list:SetRowHeight: s6-modular-g,
--- 7.x's lists are 4a's rows), as it is also the list's scroll step. When a list shows its end, where a board's list asks
--- the model for older rows (AtEnd: the wire's timing), is 7.5.2's own geometry's (list.logical, below). A look may
--- also draw the rows its own way (list.styleRow(row) when a row is made,
--- list.paintRow(row, selected) when the selection changes).
--- Every list is one of 4a's ListPanes (the boards, mail, trade, item and spell menus, NPC questions, the bank, the
--- powers, the user list), whose press outside the rows picks a row (below). own = true for a list 4a draws with a pane
--- of its own that does not (the rankings' RankingEventListPane::HitTestRow 0x0045BD10): a press there picks nothing.
--- paneBar: such a pane's own scroll bar (the rankings' categories: RankingEventScrollPane), its rectangle's insets in
--- the list's, in 4a's pixels ({ top, bottom, right, width }: RankingEventListPane::UpdateRenderRegion 0x0045AF70 puts
--- it 4 below the list's top, 10 above its bottom, 3 left of its right edge, 15 wide). Its bar takes a wheel turn,
--- and a held move of its thumb does not move the list (list:ThumbPress below).
function K.List(win, index, width, height, multi, own, paneBar)
    local sf = W.ScrollArea(win)
    sf:SetSize(width, height)
    -- s6-characters (round 46, step 6): the list's background and its rows' look are the look's (L.List: the default's)
    local drawing = look().List
    sf.bg = drawing.background(sf) -- s6-modular-g: a look may draw the list on its own background
    -- anchor: ListPane's m_selectedIndex (the last row picked, flagged or not), the arrows' start and Shift's other end.
    local list = { sf = sf, rows = {}, items = {}, selected = {}, index = index, multi = multi, anchor = nil, rowHeight = 20 }
    win.controls[index] = sf
    sf.__dialogWin, sf.__dialogControl = win, index
    sf.list = list -- s6-ui-core: a pooled window's lists start again for a new dialog (main.lua's takeWindow)
    -- 4a's wheel event and a press on the scroll bar reach the list, which asks for older rows once it shows its end
    -- (ArticleListPane::HandlePointerOrMouseEvent 0x00474EC0; review r4, 6): each goes to the model with the values
    -- after the scroll. The wheel moves 4a's position (below) by its notches; a look's own drawn list (list:OwnDrawn)
    -- scrolls by W.ScrollArea's step too, a list drawn at 4a's position follows the position.
    -- Client review 2.47 (Astra's passes 21, 23 to 25): after a page's rebuild under the kit's held thumb, a look's
    -- own drawn list follows 4a's position until the release, not its drawn drag or its wheel step (list:ToTop,
    -- setLogical)
    local drawnFollows
    local wheel = sf:GetScript("OnMouseWheel")
    sf:SetScript("OnMouseWheel", function(self, delta)
        -- Client review 2.44 (Astra's passes 8 to 11). WIRE: 4a's DialogPane hit-tests its own controls at the point
        -- (DialogPane.cpp:388; the shield's moved point while a slide holds a press) and its list turns only over its
        -- rows: the bar takes no wheel and the list's wheel bounds leave the bar out (ScrollPane.cpp:111, :1054), except
        -- a list with a pane's own bar (paneBar: the rankings' RankingEventListPane takes a turn anywhere in its
        -- bounds, bar included, RankingEventScrollPane.cpp:580, :725; its first row is the next 7D 02's; the rankings'
        -- table is RankingUserListPane, which has no bar and no wheel, RankingUserListPane.cpp:10, :53). While
        -- this list's bar holds the press the wheel comes here wherever the pointer is (holdBar): over another list of
        -- the dialog it turns that one, outside the dialog's place the side panel's page there (sidePaneWheel), and
        -- elsewhere nothing. Changing it changes which list turns, so whether 3B 02 goes, or the spell row a click casts.
        local x, y
        if win.__pointAt then x, y = win.__pointAt() else x, y = TK.Util.CursorRoot() end
        local hit, bar = hitAt(win, x, y)
        if K.heldBar == list and hit ~= index then
            local other = win.controls[hit]
            if other and other.list then other:GetScript("OnMouseWheel")(other, delta)
            elseif hit < 0 and not within(win, x, y) then sidePaneWheel(delta) end
            return
        end
        if bar and not paneBar then return end
        -- 2.47 (Astra's pass 25): a followed list draws 4a's position in MoveLogical (setLogical), not the
        -- widget's step
        if list:OwnDrawn() and not drawnFollows then wheel(self, delta) end
        list:MoveLogical(-delta) -- 4a's own position (below), before the values go
        K.Wheel(win, index)
    end)
    -- One logical row a notch (ScrollablePane::HandlePointerOrMouseEvent 0x0055EF50: the position less the notches;
    -- review r6, 4).
    sf.wheelStep = 20
    if sf.thumb then
        local thumb = sf.thumb
        -- The thumb's press and release go to the model as K.Wire's do, 4a's own thumb first (list:ThumbPress below: a
        -- press 4a's bar would not take goes as a miss).
        thumb.__dialogWin, thumb.__dialogControl = win, index
        thumb:HookScript("OnMouseDown", function(_, button, double)
            local part = K.BAR_HIT -- client review 2.40: the bar's press, not a row's (K.BAR_HIT)
            -- Client review 2.40 (pass 111; Astra's pass 6). WIRE: 4a's bar takes an ordinary press only
            -- (ScrollPane.cpp:111), so a double's second press tracks nothing: it moves no position and starts no drawn
            -- drag (thumb.__double, OnDragStart below; the model ignores it too: Dialog.Click). Arming the thumb there
            -- moves the list, so the row a later click sends (an NPC answer's 3A) or the end the list pages at (3B 02)
            -- is not 4a's; changing it changes what the server sees.
            if button == "LeftButton" then
                thumb.__double = double
                if not double then
                    part = list:ThumbPress() or K.BAR_HIT
                    if part ~= K.ROW_MISS then holdBar(list) end -- 2.44: the bar holds the input (K.BarHeld)
                end
            end
            K.Pointer(win, index, button, true, part)
        end)
        thumb:HookScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then list:ThumbRelease() end
            local over, overPart = controlUnderPointer(win)
            K.Pointer(win, over, button, false, overPart)
        end)
        -- 2.44 (Astra's pass 9): a swallowed release lets the bar go and posts nothing (K.CancelPress)
        thumb:HookScript("OnPressCancelled", function(_, button) if button == "LeftButton" then K.CancelPress(win) end end)
        -- s6-interface-5x (round 7). W.ScrollArea's own drag (the drawn scroll, a continuous fraction of the bar) only
        -- where it is not 4a's position: a look's own drawn list (list:OwnDrawn), or a list that does not page. A paging
        -- list drawn at 4a's position follows 4a's thumb instead (list:ThumbPress), so its drawn and paged position are one.
        -- Client review 2.44 (Astra's pass 11). WIRE: a pane's own bar (paneBar) takes no drag at all: 4a's
        -- RankingEventScrollPane sets the position at the press only (BeginPartInteraction,
        -- RankingEventScrollPane.cpp:476), a held move redraws its thumb at the pointer and moves nothing (:113-119,
        -- :427) and its timer is Pane::OnTimer, so a wheel turn while it is held stays (:725). The drag wrote its old
        -- offset over the turn, so the next 7D 02 named another category. The shield's presses come here too
        -- (K.PressAt). Changing it changes that category.
        local dragStart = thumb:GetScript("OnDragStart")
        thumb:SetScript("OnDragStart", function(...)
            if not thumb.__double and not paneBar and (list:OwnDrawn() or not list.logical) then
                dragStart(...)
                -- 2.47: its frames stop after a rebuild under it (list:ToTop)
                thumb:SetScript("OnUpdate", function() if not drawnFollows then thumb.DragStep() end end)
            end
        end)
        -- A move while the thumb is held drags it, then goes to the list (review r6, 3: older rows before the release);
        -- a pane's own bar's thumb is drawn under the pointer instead (list:PaneThumbAt).
        thumb:SetScript("OnPressedMove", function()
            if paneBar then list:PaneThumbAt() elseif thumb.DragStep and not drawnFollows then thumb.DragStep() end
            list:ThumbDragged()
            K.Move(win, index)
        end)
    end

    -- s6-interface-5x (Astra's reviews of 5.x rounds 4 to 7, P1). Wire: 7.5.2's own scroll position, on 7.5.2's own
    -- geometry, in every look. A list that pages (the article and mail lists) declares 7.5.2's view for it:
    -- list.logical = { height = view pixels, row = row pixels }, in 4a's pixels, set by its component (bulletin.lua) for
    -- every look. Every other list's 4a view is the drawn one (its rows are 4a's rows). The list keeps the position 4a's
    -- list would be at (list.logicalRow, in 4a's rows), and its range, its held press and its thumb run on that geometry,
    -- whatever the look draws. A look that draws the list at that geometry (7.x; every list without list.logical) is
    -- drawn at that position; one that draws it otherwise (Modern's 290 pixels of 20-pixel rows, 5.33's 224 of 14) keeps
    -- its own drawn scroll (W.ScrollArea's) apart from it (list:OwnDrawn). The pointer is taken onto 4a's view by the
    -- views' heights (the drawn list's top and bottom are 4a's), a thumb's drag onto 4a's bar by the bars' travels
    -- (decision 2026-10-04-paging-lists-pointer-on-752s-view). Only what moves 4a's list moves the position:
    -- - the wheel: the position less its notches (ScrollablePane::HandlePointerOrMouseEvent 0x0055EF50);
    -- - the keys: the chosen row brought into the view (ListPane::ScrollItemIntoView 0x004F4920, from SelectNext and
    --   SelectPrevious), by whole rows;
    -- - a held press on the rows (ListPane::OnMouseEvent 0x004F4190): each move takes the row HitTestItem (0x004F4480)
    --   finds on 4a's scrolled rows (the position plus the rows above the pointer, clamped to the rows) into the view,
    --   so a pointer held below the list moves it on a row each move, as 4a's moves do; the left release likewise when
    --   inside the view;
    -- - the thumb of a paging list (ScrollPane, EPF): 4a's UpdatePositionFromCursor (0x0055E210) on 4a's bar (its view's
    --   height, the 38-pixel thumb) from 4a's own thumb, at the press and on ScrollPane's timer (BeginPartPress 0x0055DF10:
    --   200 ms, then OnTimer 0x0055C610 every 30 ms); a move only redraws 4a's bar, so it does not move the position.
    --   Another list's thumb drags its drawn list as W.ScrollArea does, and the position takes the row it shows (nothing
    --   is paged on it);
    -- - a reused window: back to 0.
    -- AtEnd reads it against 4a's range for 4a's view (ListPane::GetScrollRange 0x004F3F20), so a board's list asks for
    -- older rows (3B 02: MailListPane 0x0047AD80, ArticleListPane 0x00474EC0, after the list handled the event) where
    -- 4a's would, however a look draws the list. Changing the geometry, the mappings or any of these changes when the
    -- server gets 3B 02. A bar part that scrolls the list (a look's arrows or track) moves it with list:MoveLogical too.
    -- While a row press is held, 4a's EventMan also posts a move at the pointer every 20 ms (ScheduleAutoScrollTick
    -- 0x004A8F60, EventMan::OnTimer 0x004AA200): the input host posts it (s6-input round 42, H:DialogListTracks below),
    -- and each such move takes the held press's step below like any other move.
    list.logicalRow = 0

    --- The drawn list's view height and row height: the look's pixels. Client review 2.47: the height the look placed
    --- it at (list.drawnHeight, dialogkit.lua's X.List) where it says so, as the frame's own comes back snapped to the
    --- screen's pixels (236.8 for 7.x's 236-high user list column), which made a list drawn at 4a's size its own
    --- (list:OwnDrawn).
    local function drawn() return list.drawnHeight or math.floor(sf:GetHeight() + 0.5), list.rowHeight end

    --- 4a's view height and row height, 4a's pixels: list.logical's, else the drawn ones.
    local function geometry()
        if list.logical then return list.logical.height, list.logical.row end
        return drawn()
    end

    --- Whether the look draws the list at another geometry than 4a's, so its drawn scroll is its own (W.ScrollArea's)
    --- and 4a's position is kept apart from it.
    function list:OwnDrawn()
        if not self.logical then return false end
        local h, rh = drawn()
        return h ~= self.logical.height or rh ~= self.logical.row
    end

    --- 4a's GetScrollRange (0x004F3F20) for its view, in rows: the rows that do not fit, rounded up, but 1 for rows
    --- exactly as tall as the view. Astra's pass 13 and the client reviewer's pass 113. WIRE: a pane's own bar
    --- (paneBar, the rankings' categories) is 0 there, RankingEventListPane::ComputeVisibleRowRange's count - 10
    --- (0x0045B080), so its bar takes no press (list:ThumbPress, KitTrackPress); 1 made it hold the press and take the
    --- window's keys.
    local function logicalRange()
        local h, rh = geometry()
        local excess = #list.items * rh - h
        if excess == 0 and #list.items > 0 then return paneBar and 0 or 1 end
        if excess <= 0 then return 0 end
        return math.floor((excess + rh - 1) / rh)
    end

    --- The drawn list scrolled to 4a's position: its first row shown is 4a's (by whole rows, as 4a's content moves:
    --- ListPane::GetContentOffset 0x004F4140).
    local function showLogical()
        sf:SetVerticalScroll(math.min(sf:GetVerticalScrollRange(), list.logicalRow * list.rowHeight))
        sf.Refresh()
    end

    --- 4a's ApplyScrollPosition: the position, kept within its range; a list drawn at 4a's position scrolls to it, as
    --- does a look's own drawn list while it follows the position (drawnFollows, 2.47: list:ToTop).
    local function setLogical(row)
        list.logicalRow = math.max(0, math.min(logicalRange(), row))
        if drawnFollows or not list:OwnDrawn() then showLogical() end
    end

    --- 4a's position moved by rows (the wheel: less its notches; a look's bar part).
    function list:MoveLogical(rows)
        setLogical(self.logicalRow + rows)
    end

    --- ListPane::ScrollItemIntoView (0x004F4920) on 4a's view: row i (1-based) brought into it by whole rows.
    local function logicalIntoView(i)
        local h, rh = geometry()
        local top = (i - 1 - list.logicalRow) * rh
        if top < 0 then
            setLogical(list.logicalRow - (math.floor((-top - 1) / rh) + 1))
        elseif top + rh > h then
            setLogical(list.logicalRow + (math.floor((top + rh - h - 1) / rh) + 1))
        end
    end

    --- A look's own drawn list (list:OwnDrawn) scrolled just enough to show row i (1-based): drawing only, 7.5.2's
    --- position is logicalIntoView's.
    local function drawnIntoView(i)
        local rh = list.rowHeight
        local top, h, s = (i - 1) * rh, sf:GetHeight(), sf:GetVerticalScroll()
        if top < s then sf:SetVerticalScroll(top)
        elseif top + rh > s + h then sf:SetVerticalScroll(top + rh - h) end
        sf.Refresh()
    end

    --- The pointer below the drawn list's top (the look's pixels), and whether it is across the list: while a slide's
    --- shield holds a press, at the shield's moved point (win.__pointAt, dialogkit.lua X.SlideOpen; client review 2.44).
    local function pointer()
        local x, y
        if win.__pointAt then x, y = win.__pointAt() else x, y = TK.Util.CursorRoot() end
        local l, b, w, h = TK.Util.RootRect(sf)
        return (b + h - y) / sf:GetEffectiveScale(), x >= l and x < l + w
    end

    --- ListPane::OnMouseEvent (0x004F4190) on 4a's view: on a move while the row press is held, and on the left release
    --- inside the view (release), the row HitTestItem (0x004F4480) finds on 4a's rows as they are scrolled now (the
    --- position plus the rows above the pointer, clamped to the rows) brought into the view. The pointer is on 4a's view
    --- by the views' heights (the drawn top and bottom are 4a's). It reads the position the last event left, so moves held
    --- below the list go on scrolling it. A look's own drawn list then follows its own row under the pointer the same
    --- way (drawing only: Astra's self-review of round 8).
    local function logicalFollow(release)
        local n = #list.items
        if list.own or n == 0 then return end -- an own list is no ListPane (above): its pane does not track
        local h, rh = geometry()
        local drawnBelow, across = pointer()
        local below = drawnBelow * h / drawn()
        if release and (not across or below < 0 or below >= h) then return end
        local at = math.max(0, math.min(n - 1, list.logicalRow + math.floor(below / rh))) + 1
        logicalIntoView(at)
        if list:OwnDrawn() then
            at = math.max(0, math.min(n - 1, math.floor((sf:GetVerticalScroll() + drawnBelow) / list.rowHeight))) + 1
            drawnIntoView(at)
        end
        -- Client review 2.41. WIRE: a followSelects list (the Power dialog's columns) also selects the row it follows,
        -- on each held move and on the release inside its view, as PowerListPane::OnMouseEvent does (OnItemSelected at
        -- PowerDialogPane.cpp:399 and :420; ListPane's own only scrolls), the row the press picked in a look's own
        -- drawn list; A to COLOR's 4C 02 then names that row's power. Only an ordinary left press follows
        -- (__followPress, below): 4a's tracking flag is set by event 1 alone (PowerDialogPane.cpp:388) and its move and
        -- release test it (:405, :416), so a double-click's second press keeps its own row. Changing it changes the id
        -- the server gets.
        if list.followSelects and list.__followPress then list:Pick(at) end
    end

    --- Client review 2.41 (Astra's passes 5 and 13). WIRE: the press that follows (logicalFollow's selection) is an
    --- ordinary left press that hit a row, a press below the rows included (HitTestItem's clamp, ListPane.cpp:329;
    --- PowerDialogPane.cpp:388 sets the tracking for event 1 alone), on each path a press takes: a row's own, the
    --- list's background and a slide's shield (K.PressAt). Its release follows to the row under it first and ends it
    --- (:415-427), before the release is posted. A path that skipped either left the pressed power selected, so A to
    --- COLOR's 4C 02 named it; changing it changes that power.
    function list:FollowPress(ordinary) self.__followPress = ordinary end

    function list:FollowRelease()
        logicalFollow(true)
        self.__followPress = false
    end

    -- 4a's thumb (ScrollPane with EPF art): its bar as tall as 4a's view, the thumb kScrollPanePartExtentBySkin's 38.
    local THUMB = 38
    local thumbDrag -- while the thumb is held: 4a's thumb top at the press, the scale, the pointer then, the next tick
    local thumbGrab = 0 -- the last thumb press's 4a pixels into 4a's thumb (m_thumbDragOffset): a track press uses it
    local ticker = CreateFrame("Frame", nil, sf)

    --- 4a's track (its thumb's travel), 4a's pixels: the bar is 4a's view tall (ScrollPane, EPF), or a pane's own bar's
    --- rectangle in it (paneBar; client review 2.45: 418 for the rankings' 470).
    local function track4a()
        return geometry() - THUMB - (paneBar and paneBar.top + paneBar.bottom or 0)
    end

    --- The kit's own drawn bar (W.ScrollArea's track, where the look puts it): its top below the list's top, its
    --- thumb's travel, and its thumb as drawn (its top below the track's top, and its height; none for a thumb not
    --- laid out yet, Astra's pass 13), the look's pixels.
    local function kitBar()
        local s = sf:GetEffectiveScale()
        local _, sb, _, sh = TK.Util.RootRect(sf)
        local _, tb, _, th = TK.Util.RootRect(sf.track)
        local _, ub, _, uh = TK.Util.RootRect(sf.thumb)
        local h = sf.thumb:GetHeight()
        return (sb + sh - tb - th) / s, th / s - h, ub and (tb + th - ub - uh) / s, ub and h
    end

    --- 4a's track over a drawn bar's thumb travel (a look's own, else the kit's thumb's): 4a pixels per drawn pixel.
    local function scale(travel)
        travel = travel or select(2, kitBar())
        return travel > 0 and track4a() / travel or 1
    end

    --- Client review 2.46. WIRE: a press's pointer on 4a's bar, in 4a's pixels below its top; y is the pointer's
    --- drawn pixels below where the drawn thumb's way starts. With the kit's drawn thumb (its top there, thumbTop, and
    --- its height, thumbH) each drawn part maps onto 4a's: the thumb onto 4a's thumb (38 tall, at top, 4a's thumb
    --- top), the drawn track above and below it onto 4a's track on that side. So a press just below a proportional
    --- thumb (Modern's, the 5.x fallback's) is just below 4a's thumb, not the share of the whole bar its distance from
    --- the top would be. Without it (5.33's bar, whose 13-pixel thumb is near 4a's on 4a's scale) the pointer is on
    --- 4a's bar by the bars' travels (scale; decision 2026-10-04-paging-lists-pointer-on-752s-view). travel: the
    --- drawn thumb's way. It decides the row a track press jumps to and a thumb press's offset into the thumb
    --- (HitTestPart, DragToPosition), so the rows a later click sends (3A, 7D 02) and when the list pages (3B 02);
    --- changing it changes what the server sees.
    local function on4aBar(y, travel, top, thumbTop, thumbH)
        if not thumbTop or thumbH <= 0 then return math.floor(y * scale(travel)) end
        if y < 0 then return 0 end -- above the drawn way: 4a's bar's top
        if y < thumbTop then return math.floor(y * top / thumbTop) end
        local below = y - thumbTop - thumbH
        if below < 0 then return top + math.floor((y - thumbTop) * THUMB / thumbH) end
        local rest = travel - thumbTop -- the drawn track below the thumb
        return top + THUMB + (rest > 0 and math.floor(below * (track4a() - top) / rest) or 0)
    end

    --- ScrollPane::UpdatePositionFromCursor (0x0055E210), vertical, EPF: 4a's thumb top moved by the pointer's 4a pixels
    --- since the press (the press's offset into the thumb cancels out), plus one, kept on 4a's track (view - 38); the
    --- position is (range + 1) x that top / the track, truncated, at most the range.
    local function thumbFollow()
        local range, track = logicalRange(), track4a()
        if not thumbDrag or range <= 0 or track <= 0 then return end
        local top = thumbDrag.top + math.floor(pointer() * thumbDrag.k) - thumbDrag.y + 1
        top = math.max(0, math.min(track, top))
        setLogical(math.min(range, math.floor((range + 1) * top / track)))
    end

    --- The thumb's left press (ScrollPane::HandlePointerOrMouseEvent 0x0055C400, BeginPartPress 0x0055DF10), for a list
    --- that pages. With 4a's thumb shown (IsScrollThumbVisible: a range above 0) the drag starts from 4a's thumb
    --- (GetScrollPartRect: the position x the track / the range), the position follows at once (ProcessActivePart) and
    --- then on the timer, 200 ms, then every 30 ms (OnTimer 0x0055C610). The drawn thumb's movement counts on 4a's bar by
    --- the bars' travels (4a's track over the drawn bar's), so the drawn thumb's whole way is 4a's. With a range of 0,
    --- 4a's bar takes neither the press nor the moves and release after it: the press goes as K.ROW_MISS (returned), so
    --- the list takes none of them and asks for nothing. travel: a look's own drawn thumb's way (list:BarPress), else the
    --- kit's thumb's; arrow: where that way starts below the bar's top (its top arrow), for the offset a later track
    --- press uses (list:TrackPress).
    --- Client review 2.44 (Astra's pass 6): every list's thumb press sets 4a's grab (m_thumbDragOffset), which the kit's
    --- own track's press uses for any list (list:KitTrackPress). WIRE: it places that jump, so the row a later click
    --- sends or the end the list pages at (3B 02); changing it changes what the server sees.
    --- Client review 2.45 and Astra's pass 11. WIRE: a pane's own bar (paneBar, the rankings' categories) is 4a's
    --- RankingEventScrollPane: on its rectangle (track4a, the drawn bar's top and travel mapped onto it), the
    --- thumb's press takes its offset into the thumb and moves it to the pointer less that offset, plus one
    --- (BeginPartInteraction and DragToPosition, RankingEventScrollPane.cpp:476, :510-537), so the position is
    --- (range + 1) x (its top + 1) / the track, at most the range; nothing moves it after (the timer is
    --- Pane::OnTimer, a move only redraws). That position is the first category a later press asks for (7D 02);
    --- changing it changes the category.
    local paneThumb -- while a pane's own bar's thumb is held: the pointer and the drawn thumb's top at the press
    function list:ThumbPress(travel, arrow)
        thumbDrag, paneThumb, drawnFollows = nil, nil, nil
        local kit = not travel -- the kit's own thumb, not a look's bar (2.47: list:ToTop)
        local range, track = logicalRange(), track4a()
        -- Astra's pass 13. WIRE: 4a's ranking bar takes no press while nothing scrolls (IsScrollable,
        -- RankingEventScrollPane.cpp:100, :121-123), so the press is the list's (K.ROW_MISS: no hold), and its release
        -- asks for the category under it (client review 2.28). Holding it took the window's keys.
        if paneBar and range <= 0 then return K.ROW_MISS end
        -- The kit's drawn thumb (on4aBar, client review 2.46); a look's own bar passes its travel.
        local thumbTop, thumbH
        if not travel then arrow, travel, thumbTop, thumbH = kitBar() end
        local k = scale(travel)
        local top = range > 0 and math.floor(self.logicalRow * track / range) or 0
        if range > 0 then
            local at = on4aBar(pointer() - (arrow or 0), travel, top, thumbTop, thumbH)
            thumbGrab = math.max(0, math.min(THUMB - 1, at - top))
        end
        if paneBar then
            if track > 0 then
                setLogical(math.min(range, math.floor((range + 1) * math.min(track, top + 1) / track)))
            end
            if not thumbTop then thumbTop = select(3, kitBar()) end
            paneThumb = { at = pointer(), top = thumbTop or 0 }
            return nil
        end
        if not self.logical then return nil end
        if range <= 0 then return K.ROW_MISS end
        thumbDrag = { top = top, k = k, y = math.floor(pointer() * k), due = GetTime() + 0.2, kit = kit }
        thumbFollow()
        ticker:SetScript("OnUpdate", function()
            local now = GetTime()
            if not thumbDrag or now < thumbDrag.due then return end
            thumbFollow()
            thumbDrag.due = now + 0.03
        end)
        return nil
    end

    --- s6-ui-core (round 98, Astra's self-review): a left press on 4a's track above (part 1) or below (3) its thumb, for
    --- a list that pages (BeginPartPress 0x0055DF10, ProcessActivePart 0x0055DFD0, EPF). The pointer is on 4a's bar by
    --- the bars' travels from where the drawn thumb's way starts (arrow); 4a's EPF bar has no arrows (GetScrollPartRect's
    --- are empty), so a look's own arrows are its track. If the pointer is on that side of 4a's thumb (HitTestPart; the
    --- thumb's top the position x the track / the range), the thumb jumps to it less the last thumb press's offset
    --- (UpdatePositionFromCursor 0x0055E210: plus one, kept on the track, the position (range + 1) x that top / the
    --- track, at most the range). Only at the press: once the bar is held, 4a's thumb is under the pointer
    --- (m_thumbDragActive, GetScrollPartRect 0x0055D9E0), so the timer's steps find no track. With a range of 0,
    --- K.ROW_MISS, as the thumb's. WIRE: the position it leaves is the one the list's end is read from after the press
    --- (3B 02); moving it again while the press is held, or otherwise, changes when the server gets 3B 02.
    --- trackJump: the jump, with a range above 0 (part nil: the side of 4a's thumb the pointer is on, list:KitTrackPress).
    --- A pane's own bar (paneBar) jumps the same way on its rectangle (RankingEventScrollPane's
    --- UpdateActiveInteraction, :490-507: DragToPosition with the last thumb press's offset; client review 2.45).
    local function trackJump(part, travel, arrow)
        local thumbTop, thumbH -- the kit's drawn thumb: the pointer on 4a's bar by its parts (on4aBar, 2.46)
        if not travel then arrow, travel, thumbTop, thumbH = kitBar() end
        local range, track = logicalRange(), track4a()
        if track <= 0 then return end
        local top = math.floor(list.logicalRow * track / range)
        local y = on4aBar(pointer() - (arrow or 0), travel, top, thumbTop, thumbH)
        local side = y < top and 1 or y >= top + THUMB and 3 or 2
        if side ~= 2 and side == (part or side) then
            setLogical(math.min(range, math.floor((range + 1) * math.max(0, math.min(track, y - thumbGrab + 1)) / track)))
        end
    end

    function list:TrackPress(part, travel, arrow)
        thumbDrag = nil
        if not self.logical then return nil end -- a look's own bar scrolls another list itself (5.x's)
        if logicalRange() <= 0 then return K.ROW_MISS end
        trackJump(part, travel, arrow)
        return nil
    end

    --- Client review 2.44 (Astra's passes 111 and 6): a left press on the kit's own track (W.ScrollArea's; 7.x's is 4a's
    --- 13-pixel bar right of the rows, dialogkit.lua X.List), for every list: 4a's track press (trackJump), on 4a's
    --- position, which a list drawn at it follows (setLogical); a look's own drawn list (list:OwnDrawn) is moved to the
    --- same share of its drawn scroll, so what it shows goes with what it pages at. WIRE: the position it leaves is the
    --- row a later click sends (an NPC answer's 3A) and the end the list pages at (3B 02); a list that does not page
    --- took the press and did not move, so the row was not 4a's. Changing it changes what the server sees.
    function list:KitTrackPress()
        thumbDrag = nil
        local range = logicalRange()
        if range <= 0 then return K.ROW_MISS end
        trackJump(nil)
        if self:OwnDrawn() then
            sf:SetVerticalScroll(sf:GetVerticalScrollRange() * self.logicalRow / range)
            sf.Refresh()
        end
        return nil
    end

    --- Another list's thumb (no paging, drawn at 4a's position) drags its drawn list smoothly (W.ScrollArea): the
    --- position takes the row the drawn list shows, so the wheel, the keys and a held press go on from there.
    function list:ThumbDragged()
        if self.logical then return end
        local rh = self.rowHeight
        self.logicalRow = math.max(0, math.min(logicalRange(), math.floor(sf:GetVerticalScroll() / rh + 0.5)))
    end

    --- The thumb's release (ScrollPane::ResetScrollState 0x0055E600): the timer stops, the position stays where it was.
    function list:ThumbRelease()
        thumbDrag, drawnFollows = nil, nil
        ticker:SetScript("OnUpdate", nil)
        if K.heldBar == self then holdBar(nil) end -- 2.44: every bar release ends the hold (K.BarHeld)
        self:ThumbDragged()
        -- a pane's own bar's thumb goes back to the position (RankingEventScrollPane.cpp:142-143: drawing only)
        if paneThumb then paneThumb = nil sf.Refresh() end
    end

    --- A pane's own bar's held thumb (paneBar): drawn under the pointer less the press's offset into it, kept on its
    --- track, as 4a draws it while held (m_thumbDragActive, RankingEventScrollPane.cpp:427-435); the list stays
    --- where it is. Drawing only.
    function list:PaneThumbAt()
        if not paneThumb then return end
        local _, travel = kitBar()
        local y = math.max(0, math.min(travel, paneThumb.top + pointer() - paneThumb.at))
        sf.thumb:ClearAllPoints()
        sf.thumb:SetPoint("TOPLEFT", sf.track, "TOPLEFT", 0, -y)
    end

    --- s6-ui-core (round 98): a look's own scroll bar that takes the bar's presses in place of the kit's (5.x's 5.33 bar:
    --- interfaces/5x/scrollbar.lua, Bar.ForList; its parts 0 to 4, the top arrow to the bottom one, 2 the thumb). Its
    --- thumb is 4a's thumb and the rest 4a's track on that side (list:ThumbPress, list:TrackPress, from that bar's thumb
    --- travel and top arrow), moving 4a's position first; its press, the moves while it is held and its release then go
    --- to the model as the kit's thumb's do (above). WIRE: these are the scroll bar's events after which
    --- ArticleListPane::HandlePointerOrMouseEvent (0x00474EC0) and MailListPane's (0x0047AD80) read the list's end and ask
    --- for older rows (3B 02); posting them otherwise, or before the position moved, changes when the server gets 3B 02.
    function list:BarPress(part, travel, arrow)
        local miss
        if part == 2 then miss = self:ThumbPress(travel, arrow)
        elseif part then miss = self:TrackPress(part < 2 and 1 or 3, travel, arrow)
        else miss = self:KitTrackPress() end -- nil: the kit's own track (2.44, below)
        if not miss then holdBar(self) end -- 2.44: the bar holds the input (K.BarHeld)
        K.Pointer(win, index, "LeftButton", true, miss or K.BAR_HIT) -- 2.40: the bar's, not a row's (K.BAR_HIT)
    end

    function list:BarMove() K.Move(win, index) end

    function list:BarRelease()
        self:ThumbRelease()
        local over, overPart = controlUnderPointer(win)
        K.Pointer(win, over, "LeftButton", false, overPart)
    end

    -- Client review 2.44. WIRE: a left press on the kit's own track is 4a's track press (ScrollPane.cpp:617,
    -- BeginPartPress 0x0055DF10: list:KitTrackPress above), and the press then goes to the list as the thumb's does
    -- (K.BAR_HIT), the held moves and the release after it; ArticleListPane and MailListPane (0x00474EC0, 0x0047AD80)
    -- read the list's end after each and ask for older rows (3B 02; BulletinSession.cpp:1100, :2598). The track was a
    -- plain frame, so such a press sent nothing. A double's second press takes no track press (2.40: 4a's bar takes an
    -- ordinary press only, ScrollPane.cpp:111). A slide's shield passes its presses here too (K.PressAt). Changing it
    -- changes what the server sees.
    if sf.track then
        local track = sf.track
        track.__dialogWin, track.__dialogControl = win, index
        track:SetClaimButtons("LeftButton")
        track:SetCapturesPress(true)
        track:SetScript("OnMouseDown", function(_, button, double)
            if button ~= "LeftButton" then return end
            if double then K.Pointer(win, index, button, true, K.BAR_HIT) return end
            list:BarPress()
        end)
        track:SetScript("OnPressedMove", function() list:BarMove() end)
        track:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then list:BarRelease() end end)
        track:SetScript("OnPressCancelled", function(_, button) if button == "LeftButton" then K.CancelPress(win) end end)
    end
    -- Client review 2.44 (Astra's passes 10 and 11). WIRE: a list with a pane's own bar (paneBar: the rankings'
    -- RankingEventListPane) takes a wheel turn anywhere in its bounds, its bar included (RankingEventScrollPane.cpp:580,
    -- :725), and the kit's bar lies outside the list's area, so its thumb and track hand a turn to the list's wheel
    -- (above). Without it the turn was lost, and the first category a later press asks for (7D 02) was not 4a's.
    if paneBar then
        for _, part in ipairs({ sf.thumb, sf.track }) do
            part:EnableMouseWheel(true)
            part:SetScript("OnMouseWheel", function(_, delta) sf:GetScript("OnMouseWheel")(sf, delta) end)
        end
    end

    --- s6-ui-core (round 99, round 98's final review P1): a reused window's list is a new dialog's (main.lua's
    --- takeWindow). WIRE: 4a builds a new ScrollPane for each dialog (ScrollPane::ScrollPane 0x0055C200), its thumb offset
    --- (m_thumbDragOffset) 0, so the last dialog's grab no longer places a track press (list:TrackPress): with it, a
    --- press 106 pixels down a 20-letter list stayed at position 0 and the 3B 02 the original asks there was not sent.
    --- Within one dialog the grab stays, as 4a's.
    function list:NewDialog() thumbGrab = 0 end

    -- a reused window's list starts at the top in both (main.lua's takeWindow)
    local scrollToTop = sf.ScrollToTop
    function sf:ScrollToTop()
        list:ThumbRelease()
        list.logicalRow = 0
        scrollToTop(self)
    end

    --- Client review 2.47 (Astra's passes 18 and 19). WIRE: a page's rebuild (social.lua's Users.update) puts the list
    --- at its top and nothing more. 4a's range reset (ScrollWidget_SetMaxRange, ScrollPane.cpp:52) leaves a held thumb
    --- its capture, grab and timer, and the timer's next tick puts the position back at the thumb by the new range: on
    --- a list drawn at 4a's position, thumbDrag's ticker and thumbFollow (ScrollPane::UpdatePositionFromCursor
    --- 0x0055E210, OnTimer 0x0055C610). A release before that tick leaves the top row first. Astra's passes 21 and 23:
    --- a look's own drawn list (list:OwnDrawn, the default look's) held on the kit's thumb drags its drawn rows
    --- (W.ScrollArea's) apart from that position, and the drag put the old offset back on the next frame. From the
    --- rebuild to the release it follows 4a's position instead (drawnFollows): the drag's frames and held moves stop,
    --- as 4a's move only redraws its bar (ScrollPane::HandlePointerOrMouseEvent 0x0055C400) and its release cancels
    --- the next tick (ResetScrollState 0x0055E600), and whatever moves 4a's position puts 4a's first row first
    --- (setLogical, showLogical): each of 4a's ticks, and a wheel turn (Astra's pass 24: the position less its notches,
    --- clamped, ScrollablePane::HandlePointerOrMouseEvent 0x0055EF50), over its own drawn step. A look's own bar
    --- (5.x's, list:BarPress) stays the only one to move its drawn rows. Changing it changes which name a press on the
    --- first visible row asks 85 for.
    function list:ToTop()
        self.logicalRow = 0
        scrollToTop(sf)
        if thumbDrag and thumbDrag.kit and self:OwnDrawn() then drawnFollows = true end
    end

    local function paint()
        for i, row in ipairs(list.rows) do
            row.sel:SetShown(list.selected[i] == true)
            if list.paintRow then list.paintRow(row, list.selected[i] == true) end -- s6-modular-g: a look's own rows
        end
    end

    --- s6-modular-g (interfaces): the original's row height for a list that does not page (a look's choice; the
    --- wheel moves one row a notch, as ScrollablePane's).
    function list:SetRowHeight(h)
        self.rowHeight = h
        sf.wheelStep = h
    end

    --- s6-modular-g (Astra's review of round 10): the list's width when the look sizes it otherwise than it was made
    --- (7.x's: 4a's rectangle); its rows and content take it. Input routing: a press anywhere across the list is the
    --- row's at its height, as ListPane::HitTestItem (0x004F4480) clamps a press into the cells; so changing which width
    --- the rows take changes which row a press picks, and the reply that sends it.
    function list:SetWidth(w)
        width = w
        for _, row in ipairs(self.rows) do row:SetWidth(w) end
        sf.content:SetWidth(w)
    end

    -- s6-rules-dialogs (round 34; s6-modular-g round 11's note). Wire: a press on the list's own area, outside every
    -- row, is a press on the row 4a's ListPane::HitTestItem (0x004F4480) gives: it clamps the point into the rows'
    -- content (m_scrolledContentBounds, which ScrollablePane::ComputeScrollExtent 0x0055F250 makes exactly the rows,
    -- scrolled), so below the last row it is the last row, beside a row the row at its height. The row is picked as a
    -- row's own press picks it (ListPane::OnMouseEvent 0x004F4190: OnItemSelected, then OnItemActivated on a
    -- double-click), so OK or a double-click then sends that row. Changing which row this picks, or dropping it, changes
    -- the answer the server gets for the same click. An empty list picks nothing (-1): see the miss below.
    list.own = own
    list.paneBar = paneBar -- a look draws it at its rectangle (dialogkit.lua's styleBar)

    --- The row a press at y (UIParent units) picks: HitTestItem's clamp (above); nil for an empty list, or for an own
    --- list's press that is on no row. s6-modular-g (round 13): with x too, an own list's press beside its row is on no
    --- row (a look may draw an own list's rows narrower than the list: 7.x's rankings, RankingEventListPane::HitTestRow
    --- 0x0045BD10 takes a press on a row's box only); changing it changes whether such a press picks, and sends.
    function list:RowAt(y, x)
        local n = #self.items
        if n == 0 then return nil end
        for i = 1, n do
            local left, bottom, w, h = TK.Util.RootRect(self.rows[i])
            -- Client review 2.29. Wire: a row's top edge is its own and its bottom edge the next row's, as 4a's
            -- PointInRect (K.PressAt above); y runs up here. Changing it changes the row a press on an edge picks.
            if y > bottom then
                if self.own and (y > bottom + h or (x and (x < left or x >= left + w))) then return nil end
                return i
            end
        end
        return not self.own and n or nil
    end

    --- Client review 2.28 (Astra's passes 5 and 12): the row an own pane's HitTestRow (RankingEventListPane,
    --- 0x0045BD10) finds at (x, y) in UIParent units: on the list's shown rows only (its ten boxes from its first row),
    --- so none outside the list's area, where a scrolled-out row's frame may lie. WIRE: the rankings' field 0, the
    --- category a release asks for (7D 02); changing it changes that category.
    function list:HitRow(x, y)
        if not within(sf, x, y) then return nil end
        return self:RowAt(y, x)
    end

    -- Round 35 (review r34 P1). Wire: a press that hits no row (an empty list) goes to the model marked as a miss
    -- (K.ROW_MISS): HitTestItem gives -1, and ListPane::OnMouseEvent then returns false, so 4a's list neither picks,
    -- pages nor activates; the dialog's part (the focus, the tracking, the release's command) still runs. Posting it as
    -- the list's own press made a click on an empty mailbox ask for an older page, and its double-click read and dimmed.
    if not own then
        sf:EnableMouse(true)
        -- s6-interface-5x (round 6), s6-input (round 43): the left press picked a row, so 4a's list tracks it as a
        -- row's press
        local tracking
        sf:HookScript("OnMouseDown", function(_, button, double)
            local _, y = TK.Util.CursorRoot()
            local at = list:RowAt(y)
            if at and button == "LeftButton" then
                list:Pick(at, IsShiftKeyDown(), IsControlKeyDown())
                if list.onSelect then list.onSelect(at) end
                H:DialogListTracks() -- s6-input (round 42): a press that picked a row tracks, as a row's own (below)
            end
            if button == "LeftButton" then
                tracking = at ~= nil
                list:FollowPress(at ~= nil and not double) -- 2.41 (Astra's pass 13): a press below the rows follows
            end
            K.Pointer(win, index, button, true, not at and K.ROW_MISS or nil)
        end)
        -- s6-interface-5x (round 6), s6-input (round 43; Astra's self-review of round 43). Wire: such a press tracks in 4a
        -- (ListPane::OnMouseEvent 0x004F4190 sets m_pointerTracking for any press HitTestItem gives a row), so each move
        -- while it is held, EventMan's auto-scroll tick's every 20 ms included, goes to the list as a row press's does:
        -- 4a's position takes the move's step first (logicalFollow above: HitTestItem, ScrollItemIntoView), then the
        -- values go (the article or mail list's 3B 02 at its end); a miss's moves are not the list's. Without it a press
        -- held below a short list's rows asks only once; changing the order changes when the server gets 3B 02.
        sf:SetScript("OnPressedMove", function()
            if not tracking then return end
            logicalFollow(false)
            K.Move(win, index)
        end)
        sf:HookScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then
                if tracking then list:FollowRelease() end -- 4a's position first (above), and Power's row (2.41)
                tracking = false
                -- s6-input (round 43): the list's own release, its window still open (a row's, below)
                if win.serial then H:DialogListReleased() end
            end
            local over, overPart = controlUnderPointer(win)
            K.Pointer(win, over, button, false, overPart)
        end)
    end

    --- Client review 2.28 (Astra's pass 4). WIRE: an own pickOnRelease list whose look leaves gaps between its rows
    --- (7.x's ranking categories) takes the presses there as its own: 4a's list control answers its whole rectangle
    --- (hit part 22, RankingEventScrollPane.cpp:558), tracks the press and picks the row under the release (:736-752),
    --- none in a gap. A press in a gap released over a category so asks for its page (7D 02). Changing it changes which
    --- category the server is asked for. No tracking: an own list is no ListPane (above).
    function list:TakeGaps()
        sf:EnableMouse(true)
        sf:HookScript("OnMouseDown", function(_, button) K.Pointer(win, index, button, true) end)
        sf:HookScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then
                local x, y = TK.Util.CursorRoot()
                pickOnRelease(list, x, y)
            end
            local over, overPart = controlUnderPointer(win)
            K.Pointer(win, over, button, false, overPart)
        end)
    end

    function list:Select(i, additive)
        if not self.multi or not additive then self.selected = {} end
        if i and self.items[i] ~= nil then
            if self.multi and additive then self.selected[i] = not self.selected[i] or nil
            else self.selected[i] = true end
            self.anchor = i
        elseif not additive then
            self.anchor = nil
        end
        paint()
    end

    --- ListPane::OnItemSelected (0x004F45B0): where several may be chosen, Shift adds the rows from the anchor to this one
    --- and Ctrl toggles this one; otherwise it is chosen alone. It becomes the anchor; a row out of range clears all.
    function list:Pick(i, shift, ctrl)
        if i and self.items[i] ~= nil then
            if self.multi and shift then
                local a = self.anchor or 0
                for k = math.max(1, math.min(i, a)), math.max(a, i) do self.selected[k] = true end
            elseif self.multi and ctrl then
                self.selected[i] = not self.selected[i] or nil
            else
                self.selected = { [i] = true }
            end
            self.anchor = i
        else
            self.selected = {}
            self.anchor = nil
        end
        paint()
    end

    --- ScrollItemIntoView (0x004F4920): the row scrolled just into sight, 4a's position by whole rows (above), which a list
    --- drawn at 4a's position shows; a look's own drawn list (list:OwnDrawn) scrolls just enough to show it.
    function list:ShowRow(i)
        logicalIntoView(i)
        if self:OwnDrawn() then drawnIntoView(i) end
    end

    --- The anchor row (m_selectedIndex), which a list's Read or Open acts on; nil for none.
    function list:Current()
        if self.anchor and self.items[self.anchor] ~= nil then return self.anchor end
        return nil
    end

    --- The first selected row, or nil; all of them in the list's order.
    function list:First()
        for i = 1, #self.items do if self.selected[i] then return i end end
        return nil
    end

    function list:All()
        local out = {}
        for i = 1, #self.items do if self.selected[i] then out[#out + 1] = i end end
        return out
    end

    --- The list's own keys (ListPane::OnKeyEvent 0x004F4300): Left and Up pick the row before the anchor (the last from
    --- none), Right and Down the one after (the first from none), with the key's Shift and Ctrl, and scroll it into sight;
    --- true when the key was the list's. Wire: the rows picked are the selection the dialog's reply sends (the boards'
    --- and the exchanges' lists, through the dialog model), so changing which keys count or which row a key picks
    --- changes what the server sees.
    function list:Key(key)
        local bare = TK.Util.BareKey(key)
        local n = #self.items
        if n == 0 then return false end
        local at = self:Current()
        local target
        if bare == "UP" or bare == "LEFT" then target = at and math.max(1, at - 1) or n
        elseif bare == "DOWN" or bare == "RIGHT" then target = at and math.min(n, at + 1) or 1
        else return false end
        self:Pick(target, key:find("SHIFT%-") ~= nil, key:find("CTRL%-") ~= nil)
        self:ShowRow(target)
        -- Review r21, 4: a selection by key is a selection as a click's is (the user list's columns keep one row
        -- between them: UserListPane::OnItemSelected 0x0059ED20). Client review 2.41. WIRE: but not a keyKeepsOthers
        -- list's (the Power dialog's columns): only PowerListPane's press clears the other columns
        -- (PowerDialogPane.cpp:381-383), its arrows are ListPane's own (ListPane.cpp:289) and leave them, and
        -- ApplyPowerSlot (:213-219) then sends the first column's. Changing it changes the power id in 4C 02.
        if self.onSelect and not self.keyKeepsOthers then self.onSelect(target) end
        return true
    end

    function list:SetItems(items, render, keepSelection)
        self.items = items
        if not keepSelection then self.selected = {} end
        for i = #items + 1, #self.rows do self.rows[i]:Hide() end
        for i, item in ipairs(items) do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Button", nil, sf.content)
                row:SetHeight(self.rowHeight)
                drawing.row(row) -- s6-characters (round 46, step 6): its selection (row.sel), hover (row.hl) and text (row.text)
                row.sel:Hide()
                row.__dialogParent = sf
                -- A move while a row is held goes to the list too, as 4a's to the pressed control; 4a's position takes
                -- its step first (logicalFollow above: the row on 4a's scrolled rows), and on the left release before
                -- K.Wire's release goes
                row:SetScript("OnPressedMove", function()
                    logicalFollow(false)
                    K.Move(win, index)
                end)
                -- Client review 2.41 (Astra's pass 5). WIRE: the press that may follow (logicalFollow above): an
                -- ordinary left press, not a double-click's second (event 2), whose row is its own
                -- (PowerDialogPane.cpp:388); the left release ends it. Changing it changes the id A to COLOR's 4C 02
                -- sends.
                row:HookScript("OnMouseDown", function(_, button, double)
                    if button == "LeftButton" then list:FollowPress(not double) end
                end)
                row:HookScript("OnMouseUp", function(_, button)
                    if button == "LeftButton" then list:FollowRelease() end
                end)
                -- Client review 2.28 (pickOnRelease, above): a pickOnRelease list's row is the release's, taken before
                -- K.Wire's release is posted; its press picks nothing (below).
                row:HookScript("OnMouseUp", function(_, button)
                    if button == "LeftButton" and list.pickOnRelease then
                        local x, y = TK.Util.CursorRoot()
                        pickOnRelease(list, x, y)
                    end
                end)
                local n = i
                K.Wire(win, row, index, function(button)
                    if button == "LeftButton" then
                        if not list.pickOnRelease then
                            list:Pick(n, IsShiftKeyDown(), IsControlKeyDown())
                            if list.onSelect then list.onSelect(n) end
                        end
                        -- s6-input (round 42). Wire: a left press that picks a row of 4a's ListPane tracks it and starts
                        -- EventMan's auto-scroll tick (ListPane::OnMouseEvent 0x004F4190 case 1, PowerListPane's too:
                        -- ScheduleAutoScrollTick 0x004A8F60): the host then posts a move at the pointer every 20 ms until
                        -- the left release, each reaching this row's OnPressedMove, so a list held still goes on scrolling
                        -- and paging (3B 02). The scroll bar's press, a press that hits no row and an own list's (a pane of
                        -- its own, RankingEventListPane) do not track. Changing which presses tell it changes when the
                        -- server gets 3B 02. (The host ignores it for a double click's second press, case 2.)
                        if not list.own then H:DialogListTracks() end
                    end
                end)
                -- s6-input (round 43). Wire: the left release reaches the list (its case 3), which stops a tracking list's
                -- tick (CancelAutoScrollTick 0x004A8F70), unless the window closed under the press (no serial: 4a's list
                -- is deleted then, the release goes elsewhere and the tick runs on). Changing it changes how long the
                -- server gets the tick's 3B 02.
                if not list.own then
                    row:HookScript("OnMouseUp", function(_, button)
                        if button == "LeftButton" and win.serial then H:DialogListReleased() end
                    end)
                end
                if self.styleRow then self.styleRow(row) end -- s6-modular-g: a look's own rows
                self.rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", sf.content, "TOPLEFT", 0, -(i - 1) * self.rowHeight)
            row:SetWidth(width)
            render(row, item, i)
            row:Show()
        end
        if self.anchor and self.anchor > #items then self.anchor = nil end
        -- s6-modular-g (Astra's review of round 12, 1). Wire: the content is the rows, with one row's room more when
        -- they fill the view exactly. 4a's list scrolls in rows: ListPane::GetScrollRange (0x004F3F20) is the rows that
        -- do not fit, rounded up, but 1, not 0, for rows exactly as tall as the view, and the position starts at 0; a
        -- board's list asks for older rows when the position meets that range (AtEnd below). So a full page of mail
        -- (7.x's twenty 14-pixel rows in 280) asks once scrolled a row, not at its first press. Changing the content's
        -- height changes when the older rows are asked for.
        -- Client review 2.47 (Astra's pass 20). WIRE: a list drawn at 4a's position also reaches 4a's last one, the
        -- range rounded up: 4a's content moves by whole rows (ApplyScrollPosition, ScrollPane.cpp:915;
        -- ListPane::GetContentOffset 0x004F4140, ListPane.cpp:223), so 25 rows of 12 in 236 end 72 down, not 64. The
        -- bar reads the same range. Changing it changes the row a press near the list's top picks at its end (the 85
        -- a user list's row asks).
        local rows = #items * self.rowHeight
        local view = drawn()
        local exact = not self.own and rows > 0 and rows == view -- an own list is no ListPane
        local height = exact and rows + self.rowHeight or rows
        if not self.own and not self:OwnDrawn() then
            local range = logicalRange()
            if range > 0 then height = math.max(height, view + range * self.rowHeight) end
        end
        sf.content:SetSize(width, math.max(1, height))
        setLogical(self.logicalRow) -- older rows added: the position stays, in its new range (above)
        sf.Refresh()
        paint()
    end

    --- True while the list shows its last row (the bulletin lists' paging). Wire: 4a's article and mail lists
    --- (ArticleListPane::HandlePointerOrMouseEvent 0x00474EC0, MailListPane's 0x0047AD80) ask for older rows when, after a
    --- pointer event they handled, ScrollablePane::GetScrollPosition equals GetScrollMax: here 4a's own position against
    --- 4a's range for its view (above), in every look. Changing either changes when the older rows are asked for.
    function list:AtEnd()
        return self.logicalRow >= logicalRange()
    end

    return list
end

--- Marks the model's focused control (the look's edge) and each button's enabled state (a window's own state, localEnabled,
--- where the model keeps none: the head choice's pages).
function K.ShowState(win, view)
    local enabled = {}
    for _, c in ipairs(view.controls or {}) do enabled[c.index] = c.enabled end
    for index, frame in pairs(win.controls or {}) do
        if frame.localEnabled ~= nil then enabled[index] = frame.localEnabled end
        if frame.SetEnabled and enabled[index] ~= nil and frame.GetFontString then frame:SetEnabled(enabled[index]) end
        -- s6-characters (round 46, step 6): the edge of the look that drew the window (main.lua's drawnBy), told its window
        if not frame.__focusEdge then frame.__focusEdge = (win.drawnBy or look()).FocusEdge(frame, win) end
        frame.__focusEdge:SetShown(index == view.focus)
    end
end

--- The front dialog's focus is its edit's native focus (review r4, 4): the edit the model focuses has the keyboard, and a
--- focus elsewhere (Tab to a button) takes the keyboard from it. Each frame, as an edit can take the keyboard only once
--- the host has shown and laid it out. viewRevision: the dialog revision <view> was refreshed for.
function K.SyncFocus(win, view, viewRevision)
    -- Wire: a native press (K.Pointer) focused its edit at the clicked text point, as 4a's Activate 0x00498ED0 and
    -- TextEditPane::OnMouseEvent 0x00590DE0 do in one event, ahead of the rules' published focus. Syncing to the view
    -- from before that press (clearing the box, or focusing the previous edit) re-focuses the box with select-all once
    -- the press is published, so the next key replaces the text the server receives. Compare the view's own revision:
    -- a later poll could see the publication while this view still holds the old focus.
    if win.__pressRevision ~= nil and win.__pressRevision == viewRevision then return end
    for index, frame in pairs(win.controls or {}) do
        if frame.HasFocus and frame.SetFocus and frame.ClearFocus and frame:IsVisible() then
            local has = frame:HasFocus()
            if index == view.focus and not has then frame:SetFocus()
            elseif index ~= view.focus and has then frame:ClearFocus() end
        end
    end
end

--- The player's items, for the pickers: { slot, name, count, icon, colour } for each slot that holds one (s6-modular-g:
--- icon, its ITEM.EPF picture, for a look that draws it; s6-interface-7x round 2: colour, the picture's dye).
function K.Inventory()
    local out = {}
    for slot = 1, 52 do
        local ok, name, count, _, icon, colour = H:GetItemSlot(slot)
        if ok and name then out[#out + 1] = { slot = slot, name = name, count = count or 1, icon = icon, colour = colour } end
    end
    return out
end

--- An inventory slot's letter (a-z, A-Z), as the original names them.
function K.SlotLetter(slot) return H:SlotLetter(slot) or "?" end

return K
