-- s6-interface-7x-b: 7.x's parcel and letter buttons, the original's ParcelPane (ui/ParcelPane.cpp): one 68 x 25 strip at
-- (630, 726) on the 7.x screen, in the base layer, with its parcel button (0, 0)-(30, 25) on the left and its letter
-- button (31, 0)-(62, 25) on the right (constructor 0x00546290). Two panels here, each its own frame, switch and place:
-- the parcel panel is the strip's left part (0, 0)-(31, 25), the letter panel its right part (31, 0)-(68, 25), so at their
-- default places they make the strip, its gaps included. Both draw the one pane of the dialog model (the model's
-- ParcelPane: its counts from 0x08 and whether each side was acknowledged), as the minimap's mail and parcel icons do.
--
-- Drawing (OnPaint 0x00546890, ResolveButtonFrameIndex 0x005469E0): ALERTBTN.EPF in ALERTBTN.PAL, by each button's state
-- (0 normal, 1 under the pointer, 2 pressed, 3 blinking) and whether its side has a count; every 200 ms (OnTimer
-- 0x00546810) a side with a count it has not acknowledged steps its blink (AdvanceButtonAnimation 0x00546970: the parcels
-- frames 6-13 after a three-tick wait, the letters 20-27, one resting frame between rounds), and the strip is repainted
-- then: a hover or a press shows at the next tick, as 4a's handler changes the state without repainting. A side whose
-- count went to 0 goes back to state 0 at once (SetParcelSlotData 0x005464B0). The letter's flight (FlyingParcelPane,
-- LETTER.EPF) is not built: 7.5.2 never makes one (Source-5, FlyingParcelPane).
--
-- Wire: ParcelPane::HandlePointerOrMouseEvent (0x00546610) takes a left press anywhere in the strip (it is used up there,
-- before the chat bar under it: the strip is registered after ChattingHandlePane under the BackPane, so it is asked
-- first) and a release in the strip; the release over the parcel button sends 41 while parcels wait, over the letter
-- button it opens the mail's bulletin session (3B 09) unless one exists; either acknowledges its side. Here each press
-- and release goes to the model's pane (the game layer's one press path, TK.Game.Parcels.Press: s6-input round 49,
-- separation step 4b) with the control under the pointer as 4a's
-- rectangles give it: 0 the parcel button, 1 the letter button, -1 a gap of the strip (which sends nothing). A release
-- goes to the control of the frame on top under the pointer, as the game layer finds it (s6-input rounds 50 and 51): this
-- strip's by those rectangles, another interface's parcel or letter button (over the strip or not), or none.
-- These frames are drawn over the chat bar for that reason. s6-interface-7x-b (round 2, Astra's review of round 1): 4a's
-- case 3 acts on a left release in the strip whatever pane had its press, so a release that lands here after a press
-- elsewhere goes to the model's pane too (GLOBAL_MOUSE_UP, below), unless something holds it first: a capture (the map's
-- walk, a scroll bar: the UI never clicks such a release), a dialog window's control that had the press (its own release),
-- or a newer pane in the rules' order (a popup open takes it). Changing the rectangles, the indexes, the order or which
-- releases come here changes what the server sees.

local C = TK.GetComponent("7x.parcel")
local H = __tk
local S = require("interfaces.7x.skin")
local Hud = require("interfaces.7x.hud")
local Screen = require("interfaces.screen")

-- the strip's top left on the 7.x screen
local STRIP = { 630, 726 }

-- each side: its panel (settings key and place), its part of the strip, its button's rectangle in the strip, its control,
-- its blink's first frame and the frame it starts from (the parcels wait three ticks first: m_leftAnimationFrame -3).
-- Its state: state (0-3), anim (the blink's frame), seen (the count last drawn); panel its frame.
local SIDES = {
    { key = "parcel", control = 0, name = "TK7xParcel", label = "7.x Parcel Button",
      part = { 0, 0, 31, 25 }, button = { 0, 0, 30, 25 }, first = 6, start = -3 },
    { key = "letter", control = 1, name = "TK7xLetter", label = "7.x Letter Button",
      part = { 31, 0, 68, 25 }, button = { 31, 0, 62, 25 }, first = 20, start = 0 },
}

-- s6-input (round 49, separation step 4b): the pane's counts, frames, blink and presses are the game layer's
local Parcels = TK.Game.Parcels

--- The model's count and acknowledgement for a side: count, acknowledged.
local function model(side) return Parcels.Count(side.control) end

--- The control of the side's button under the pointer by 4a's rectangle in its part, or -1 (a gap of the strip).
local function hit(side)
    local x, y = Hud.HelpLine.PointIn(side.panel)
    local b, p = side.button, side.part
    if x >= b[1] - p[1] and x < b[3] - p[1] and y >= b[2] and y < b[4] then return side.control end
    return -1
end

--- Where the pointer is on the strip for button (default the left): whether one of its frames is the frame on top under
--- it, and the control of the button under it there (or -1). s6-input (round 51, Astra's final review of round 50, P2,
--- and self-reviews 51-1 and 51-2): the frame on top (the frame a release of that button reaches, TK.ReleaseTarget: a
--- frame claiming it over the mouse focus that takes this release, such as 7.x's minimap button, else the focus), not
--- the strip's place, so a frame lying over the strip takes what reaches that point, as 4a hit-tests a release against
--- the pane that takes it there (ParcelPane::HandlePointerOrMouseEvent 0x00546610, case 3, sees only its own buttons).
--- Wire: a release over a covered part of the strip is that frame's, not the strip's 41 or 3B 09; changing it changes
--- what the server sees.
local function pointer(button)
    local focus = TK.ReleaseTarget(button)
    for _, side in ipairs(SIDES) do
        if focus ~= nil and focus == side.panel then return true, hit(side) end
    end
    return false, -1
end

-- AdvanceButtonAnimation (0x00546970, TK.Game.Parcels.Advance): state 0 waits out a negative frame, then blinks from the
-- first frame; state 3 steps and, past the eighth frame, rests (state 0) on the first; a hovered or pressed side (1, 2)
-- does not blink.
local function advance(side)
    side.state, side.anim = Parcels.Advance(side.state, side.anim, side.first)
end

--- The pointer's move, as 4a's case 0 changes the states: off the strip every side not blinking goes to 0; over a button
--- that side is under the pointer (unless pressed) and the other, unless blinking, goes to 0; over a gap nothing changes.
local function moved()
    local inStrip, over = pointer()
    for _, side in ipairs(SIDES) do
        if not inStrip then
            if side.state ~= 3 then side.state = 0 end
        elseif over == side.control then
            if side.state ~= 2 then side.state = 1 end
        elseif over ~= -1 then
            if side.state ~= 3 then side.state = 0 end
        end
    end
end

--- A side's face: ALERTBTN's frame for its state and count (ResolveButtonFrameIndex; the renderer's table).
local function face(side)
    if side.state == 3 then return side.anim end
    local frames = Parcels.Frames[side.control]
    return frames[model(side) > 0 and 2 or 1][side.state + 1]
end

function C:Paint()
    for _, side in ipairs(SIDES) do
        local f = side.panel
        -- s6-interface-5x (round 13's hotfix, a marked edit): a side turned off is not painted (it is when it shows again:
        -- Layout)
        if f and f:IsShown() then
            f.art = S.Picture(f, f.art, "ALERTBTN.EPF", face(side), "ALERTBTN.PAL", side.button[1] - side.part[1], 0, "ARTWORK")
        end
    end
end

--- Where each button's last press began: "strip" (these frames), "dialog" (a dialog window's control), or nil.
local pressedOn = {}

--- A press or release on the strip: the states as 4a's cases 1 and 3 change them, then to the model's pane: a press with
--- the control under the pointer by 4a's rectangles (-1 for a gap), a release with the control the game layer finds under
--- the pointer. s6-input (rounds 50 and 51, Astra's reviews of rounds 49 and 50, P2): that lookup takes the frame on top,
--- so a release reaches this strip's button by its rectangle only where the strip is on top; over another interface's
--- parcel or letter button, on the strip or off it, it is that button's (the strip's letter button released over Modern's
--- Mail button lying over the parcel button opens the mail, 3B 09, not 41); over any other frame, none. Wire: case 3 of
--- ParcelPane::HandlePointerOrMouseEvent 0x00546610; changing which control a release reaches changes what is sent.
local function pointerEvent(down, button)
    local _, over = pointer(button)
    if button == "LeftButton" then
        if down then
            for _, side in ipairs(SIDES) do if side.control == over then side.state = 2 end end
        else
            for _, side in ipairs(SIDES) do side.state = side.control == over and 1 or 0 end
        end
    end
    Parcels.Press(over, down, button)
end

function C:OnEnable()
    for _, side in ipairs(SIDES) do
        local f = CreateFrame("Frame", side.name, UIParent)
        f:SetFrameStrata("LOW")
        f:SetFrameLevel(12) -- over the chat bar, whose typing area runs under the strip (above)
        f:SetSize(side.part[3] - side.part[1], side.part[4] - side.part[2])
        f:EnableMouse(true)
        f:SetScript("OnMouseDown", function(_, button) pointerEvent(true, button) end)
        f:SetScript("OnMouseUp", function(_, button)
            pressedOn[button] = nil
            pointerEvent(false, button)
        end)
        f:Hide()
        -- s6-input (round 50, the round 49 review's P2): the strip's frames are the pane's controls for the game layer's
        -- release lookup, by 4a's rectangles (a gap -1), so another interface's parcel or letter button released over
        -- this button reaches it (Modern's Mail button released over the parcel button sends 41) and over a gap sends
        -- nothing (ParcelPane::HandlePointerOrMouseEvent 0x00546610, case 3). Round 51: each frame by its own side's
        -- rectangle, as the lookup asks the frame on top. Changing it changes what is sent.
        Parcels.Control(f, function() return hit(side) end)
        side.panel, side.state, side.anim, side.seen = f, 0, side.start, 0
        self:Own(f)
        local key = side.key
        side.entry = Screen.Register(f, "7x." .. key, side.label, function() return self:DB()[key].enabled == true end)
    end
    -- the pane's timer: every 200 ms the waiting sides step and the strip is repainted; a count that changed repaints at
    -- once, and a side whose count went to 0 rests (SetParcelSlotData). Drawing only.
    local driver = CreateFrame("Frame", nil, UIParent)
    local wait = 0.1 -- 4a's first tick comes 100 ms after the pane is made
    driver:SetScript("OnUpdate", function(_, elapsed)
        if not (SIDES[1].panel:IsShown() or SIDES[2].panel:IsShown()) then return end
        moved()
        local changed = false
        -- s6-interface-5x (round 13's hotfix, a marked edit): a side turned off is neither read nor stepped
        for _, side in ipairs(SIDES) do
            if side.panel:IsShown() then
                local count = model(side)
                if count ~= side.seen then
                    side.seen, changed = count, true
                    if count == 0 then side.state = 0 end
                end
            end
        end
        wait = wait - (elapsed or 0)
        if wait <= 0 then
            wait = 0.2
            for _, side in ipairs(SIDES) do
                if side.panel:IsShown() then
                    local count, acknowledged = model(side)
                    if count > 0 and not acknowledged then advance(side) end
                end
            end
            changed = true
        end
        if changed then self:Paint() end
    end)
    self:Own(driver)
    self.driver = driver
    self.ready = true
end

function C:Layout()
    if not self.ready then return end
    local db = self:DB()
    for _, side in ipairs(SIDES) do
        local d = db[side.key]
        Screen.Place(side.entry, 1024, 768, STRIP[1] + side.part[1], STRIP[2] + side.part[2], d.scale)
        side.panel:SetShown(TK.GameState:InWorld() and d.enabled == true)
    end
    -- s6-interface-5x (round 12, build 46): the timer runs only while a side shows, so with both off (Modern's or 5.x's
    -- profile) nothing of the panel runs; its OnUpdate already skipped every frame then. Drawing only.
    self.driver:SetShown(SIDES[1].panel:IsShown() or SIDES[2].panel:IsShown())
    TK.EditMode:UpdateMovers()
    self:Paint()
end

function C:ApplySettings() self:Layout() end

-- A press's start: on these frames (their own OnMouseUp takes its release), on a dialog window's control (the control
-- takes its release: K.Wire; or another interface's parcel or letter button, TK.Game.Parcels', which takes its own), or
-- elsewhere (before any script of the press: the host fires GLOBAL_MOUSE_DOWN first). Wire: a press on any of those is
-- left to its release, so changing what counts here changes which control a release reaches (41 or 3B 09).
TK.On("GLOBAL_MOUSE_DOWN", function(_, button)
    local focus = TK.PressTarget(button) -- s6-input (round 51, self-review 51-1): the frame the press reaches
    local where
    for _, side in ipairs(SIDES) do if focus ~= nil and focus == side.panel then where = "strip" end end
    while focus and not where do
        if TK.Dialogs.IsControl(focus) or Parcels.IsControl(focus) then where = "dialog" end -- s6-input (round 49, step 4b)
        focus = TK.Dialogs.Parent(focus)
    end
    pressedOn[button] = where
end)

-- 4a's case 3 (ParcelPane::HandlePointerOrMouseEvent 0x00546610): a left release in the strip is the pane's whatever pane
-- had the press, so a release landing here after a press elsewhere goes to the model's pane as a release of the strip's
-- (before the pressed frame's own OnMouseUp: the host fires GLOBAL_MOUSE_UP first). Not a release the strip's own press
-- has (its frames' OnMouseUp), nor a dialog control's; a captured release never comes here (the UI does not click it).
-- s6-interface-7x-b (round 7, Astra's self-review): nor a release while a pane that takes every pointer event shows (the
-- item box: 4a's ItemHelpPane::HandlePointerOrMouseEvent 0x004CCC40 takes it, offered to it first), so a release there
-- sends nothing. s6-input (round 51): "here" is where the strip is the frame on top (pointer); a release over a frame
-- lying over it, of another interface, is not the strip's. WIRE: changing either changes what the server sees.
TK.On("GLOBAL_MOUSE_UP", function(_, button)
    local from = pressedOn[button]
    pressedOn[button] = nil
    if button ~= "LeftButton" or from ~= nil or H:IsPointerTaken() then return end
    if pointer(button) then pointerEvent(false, button) end
end)

Screen.Follow(C, "Layout")
