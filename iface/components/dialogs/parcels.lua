-- s6-input (round 49; docs/development/interface-separation.md, step 4b and section 5.10): the bottom icons' pane, the
-- dialog model's ParcelPane (0x08's parcel and letter counts, its parcel button and its letter button), as the game layer
-- gives it to every interface: TK.Game.Parcels, beside the model it reads. One copy of what Modern's minimap icons and
-- micro menu buttons, 7.x's parcel and letter panels and 5.x's parcel icons each did: the counts, the buttons' frames and
-- blink, and the press path. The pane's own window (the renderer in components/dialogs/panes.lua) uses it too.
--
-- Wire: ParcelPane::HandlePointerOrMouseEvent 0x00546610 (ParcelPane.cpp:207). A press goes to the control pressed (0 the
-- parcel button, 1 the letter button); its release goes to the pane's control under the pointer then, and case 3 acts on
-- that one: 0 sends 41 while parcels wait, 1 opens the mail's bulletin session (3B 09) unless one exists, -1 (no button)
-- sends nothing. Every interface's parcel and letter controls come through P.Press, so changing how a press or a release
-- finds its control, or which frames count as the pane's controls, changes what the server sees.

local C = TK.GetComponent("dialogs")
local K = C.kit

TK.Game = TK.Game or {}
local P = {}
TK.Game.Parcels = P

-- ResolveButtonFrameIndex (0x005469E0): ALERTBTN.EPF's frame { plain, under the pointer, pressed } for each button (0 the
-- parcels, 1 the letters), without and with a count. Drawing only.
P.Frames = { [0] = { { 0, 1, 2 }, { 3, 4, 5 } }, [1] = { { 14, 15, 16 }, { 17, 18, 19 } } }

--- The pane's window in a live game (the model's ParcelPane), or nil.
function P.Pane()
    local win = C:Find("ParcelPane")
    return win and win.view and win or nil
end

--- A button's count (0 the parcels, 1 the letters; 0 without the pane), and whether its side was acknowledged.
function P.Count(control)
    local win = P.Pane()
    local c = win and win.view.contents or {}
    if control == 1 then return c.right or 0, c.rightAcknowledged == true end
    return c.left or 0, c.leftAcknowledged == true
end

--- AdvanceButtonAnimation (0x00546970), one 200 ms tick of a button whose side has a count it has not acknowledged: state 0
--- waits out a negative frame, then blinks (state 3) from its first frame (the parcels 6, the letters 20); state 3 steps
--- and, past its eighth frame, rests (state 0) on the first; a button under the pointer or pressed (1, 2) does not blink.
--- Returns the new state and frame. Drawing only.
function P.Advance(state, frame, first)
    if state == 0 then
        if frame < 0 then return 0, frame + 1 end
        return 3, first
    elseif state == 3 then
        frame = frame + 1
        if frame > first + 7 then return 0, first end
        return 3, frame
    end
    return state, frame
end

-- The frames outside the pane's window that are its controls (P.Control, P.Wire): frame -> 0 or 1, or a function giving
-- the control under the pointer in that frame (7.x's strip, whose frames hold its gaps: -1).
local controls = setmetatable({}, { __mode = "k" })

--- The pane's control under the pointer for a release of button, and its part: the frame on top there (the frame that
--- release reaches, TK.ReleaseTarget: a frame claiming it over the mouse focus that takes this release, else the focus;
--- round 51, Astra's self-reviews 51-1 and 51-2), when it is one of the pane's controls made here (the pane's own
--- buttons and every interface's; outside edit mode, where those frames are moved, not pressed); -1 for none or a
--- strip's gap. Wire: this is where a release finds its control (case 3 above), whichever interface's control had the
--- press: Modern's Mail button released over 7.x's parcel button is that button's 41, as a press on 4a's letter button
--- released over its parcel button (s6-input round 50, the round 49 review's P2); 7.x's letter button released over
--- Modern's Mail button lying over 7.x's parcel button is the Mail button's 3B 09, as 4a's release reaches the control
--- drawn at its point (round 51, Astra's final review of round 50, P2).
local function underPointer(button)
    local f = TK.ReleaseTarget(button)
    local c = f and controls[f]
    if c == nil or TK.EditMode.unlocked then return -1, 0 end
    if type(c) == "function" then c = c() end
    return c, 0
end

--- A press (down) on the pane's control, or a release: to the control under the pointer then (s6-input round 51: every
--- caller's release, 7.x's strip's too, so the frame on top decides). Nothing without the pane. Wire: see the file's
--- header.
function P.Press(control, down, button)
    local win = P.Pane()
    if not win then return end
    if down then
        K.Pointer(win, control, button, true)
    else
        local over, part = underPointer(button)
        K.Pointer(win, over, button, false, part)
    end
end

--- Makes frame one of the pane's controls for a release's lookup (0 the parcels, 1 the letters; nil: none now), for a
--- frame that calls P.Press itself (the Modern minimap's icons). control may be a function giving the control under the
--- pointer in frame, -1 for a gap (7.x's parcel and letter panels, hit-testing 4a's rectangles).
function P.Control(frame, control)
    controls[frame] = control
end

--- Whether frame is one of the pane's controls now (P.Control, P.Wire): it takes its own release, so an interface's own
--- release handler leaves a press that began on it alone (7.x's parcel strip; the lead's check of step 4b). Wire: see
--- the file's header.
function P.IsControl(frame)
    return controls[frame] ~= nil
end

--- Makes frame one of the pane's controls, its presses and releases going to P.Press; once per frame (P.Control changes
--- its control later: 5.x's icons take their kind as they draw). nil leaves it none, and its presses do nothing.
function P.Wire(frame, control)
    P.Control(frame, control)
    frame:HookScript("OnMouseDown", function(_, button)
        if controls[frame] ~= nil then P.Press(controls[frame], true, button) end
    end)
    frame:HookScript("OnMouseUp", function(_, button)
        if controls[frame] ~= nil then P.Press(controls[frame], false, button) end
    end)
    return frame
end

return P
