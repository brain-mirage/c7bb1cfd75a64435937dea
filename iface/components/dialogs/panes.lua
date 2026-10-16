-- s6-rules-dialogs round 7: the original's panes that are not dialogs (the clock, the parcel buttons, the Menu popup,
-- the transfer's animation) and the targeting options. Each draws its view of the dialog model; the panes open where
-- their look's open(win) puts them, not centred.
--
-- s6-modular-g (interfaces): the panes' sizes and places are the look's (C.look.Timer, Parcel, MenuPopup,
-- PlayerMenu, Transfer, Target); this file keeps what each pane does and shows.

local C = TK.GetComponent("dialogs")
local W = TK.UI
local K = C.kit

local function Art(file, frame, palette)
    local key, w, h = TK.Art.Image(file, frame, palette)
    return key, w, h
end

-- D-71: the clock (TimerPane): NUMBER.EPF digits in 35-pixel cells, frame 10 the colon, through the map's palette
-- (BARAM.PAL: the original passes none); MM:SS, or HH:MM:SS when the first packet's seconds were an hour or more. Top
-- centre, as the original's (325, 15). Text without the packs. It takes no input.
local Timer = { look = "Timer" }

function Timer.build()
    local win = CreateFrame("Frame", nil, UIParent)
    win:SetFrameStrata("HIGH")
    win.cells = {}
    for i = 1, 8 do win.cells[i] = win:CreateTexture(nil, "ARTWORK") end
    win.text = W.Label(win, "", 28, W.white)
    win.text:SetFont(28, "OUTLINE")
    C.look.Timer.place(win)
    win:Hide()
    return win
end

function Timer.update(win, view)
    local c = view.contents
    local s = c.seconds or 0
    local h, m, sec = math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60
    local glyphs = { math.floor(m / 10), m % 10, 10, math.floor(sec / 10), sec % 10 }
    if c.hours then
        table.insert(glyphs, 1, 10)
        table.insert(glyphs, 1, h % 10)
        table.insert(glyphs, 1, math.floor(h / 10) % 10)
    end
    C.look.Timer.fit(win, #glyphs)
    local drawn = true
    -- s6-interface-5x-b (round 6): a look with its own digits draws a cell itself (5.x's: 5.33's NUMBER.EPF); true when
    -- it did, false without its picture. Drawing only.
    local glyph = C.look.Timer.glyph
    for i, cell in ipairs(win.cells) do
        local key, w, ht
        if glyphs[i] and glyph then
            key = glyph(win, cell, i, glyphs[i]) or nil
        elseif glyphs[i] then
            key, w, ht = Art("NUMBER.EPF", glyphs[i], "BARAM.PAL")
        end
        if key and glyph then
            cell:Show()
        elseif key then
            cell:SetTexture(key)
            cell:SetSize(w, ht)
            cell:Show()
        else
            cell:Hide()
            if glyphs[i] then drawn = false end
        end
    end
    local text = {}
    for _, g in ipairs(glyphs) do text[#text + 1] = g == 10 and ":" or tostring(g) end
    win.text:SetText(drawn and "" or table.concat(text))
    if not drawn then for _, cell in ipairs(win.cells) do cell:Hide() end end
end

C.renderers.TimerPane = Timer

-- D-74: the saved notice (SelfSaveOKPane, 0x005147D0, MapPane.cpp:5727-5738): string 61's line at (14, 456)-(422, 468),
-- added as the BackPane's last child on the base layer. The MapPane covers that rectangle from the frame layer
-- ((-48, -48)-(864, 768), MainMenuPane.cpp:518-522), and the frame layer draws over the base layer (WinMain.cpp:196-201),
-- so the original never shows it (the gate's saved-notice pictures, round 29). The model keeps the pane for its second;
-- its window draws nothing.
local Saved = { hidden = true }

function Saved.build()
    local win = CreateFrame("Frame", nil, UIParent)
    win:Hide()
    return win
end

function Saved.update() end

C.renderers.SelfSaveOKPane = Saved

-- D-76: the parcel (0) and letter (1) buttons (ParcelPane: ALERTBTN.EPF with ALERTBTN.PAL), beside the micro menu. A
-- side with a count it has not acknowledged blinks every 200 ms (AdvanceButtonAnimation: frames 6-13 and 20-27, one
-- plain frame between rounds); the pointer over a button or pressing it shows its lit or pressed frame. Round 27 (the
-- owner): drawn in Modern's "Mail and Parcels" panel (interfaces/modern/panels/mailparcels), off by default; hidden, the
-- model's pane is the same, and the minimap's mail and parcel icons are its controls.
-- Wire: ParcelPane::HandlePointerOrMouseEvent 0x00546610 (and its keys 0x005465E0): a press on a button goes to its
-- control (0 the parcels, 1 the letters), its release to the control under the pointer (ParcelPane.cpp:207); changing
-- the indexes changes what the server sees.
local Parcel = { look = "Parcel" }
local Parcels = TK.Game.Parcels -- s6-input (round 49, separation step 4b): the pane's frames, blink and presses

-- ResolveButtonFrameIndex (0x005469E0): { plain, lit, pressed } without and with a count (TK.Game.Parcels.Frames).
local FRAMES = Parcels.Frames

local function paint(win)
    local c = win.view and win.view.contents or {}
    for i = 0, 1 do
        local b = win.buttons[i]
        local count = (i == 0 and c.left or c.right) or 0
        local frame
        if b.state == 3 then frame = b.frame
        else frame = FRAMES[i][count > 0 and 2 or 1][(b.pressed and 3) or (b.over and 2) or 1] end
        local key = Art("ALERTBTN.EPF", frame, "ALERTBTN.PAL")
        if key then
            b.tex:SetTexture(key)
            b.tex:SetVertexColor(1, 1, 1, 1)
            b.label:SetText("")
        else
            b.tex:SetTexture("tk:white")
            local lit = (b.state == 3 and b.frame % 2 == 0) and 1 or 0.55
            b.tex:SetVertexColor(0.3 * lit, 0.3 * lit, 0.45 * lit, 1)
            b.label:SetText((i == 0 and "P" or "L") .. (count > 0 and count or ""))
        end
    end
end

-- AdvanceButtonAnimation (0x00546970), TK.Game.Parcels.Advance (a button here is in state 0 or 3: its hover and press are
-- b.over and b.pressed).
local function advance(b, first)
    b.state, b.frame = Parcels.Advance(b.state, b.frame, first)
end

-- s6-characters (round 46, step 6 of the interface separation): the parcel window's own parent (it was Modern's Mail and
-- Parcels panel's frame), hidden until a panel that draws the buttons takes it into its frame (Modern's: SetParent, its
-- points, Show), so the window shows, moves and fades with that panel. Without one it stays hidden and the model's pane
-- is the same: the minimap's icons and 7.x's and 5.x's own panels are its controls. A panel gives it back to UIParent,
-- hidden, when its frame hides (round 47), so a panel unloaded with its frames leaves the window. Drawing only.
local parcelParent

--- The parcel window's parent (TK.Dialogs.ParcelParent).
function C:ParcelParent()
    if not parcelParent then
        parcelParent = CreateFrame("Frame", nil, UIParent)
        parcelParent:Hide()
    end
    return parcelParent
end

function Parcel.build()
    local L = C.look.Parcel
    local win = CreateFrame("Frame", nil, C:ParcelParent())
    win:SetFrameStrata("MEDIUM")
    L.place(win)
    win.buttons = {}
    for i = 0, 1 do
        local b = CreateFrame("Button", nil, win)
        L.button(win, b, i)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints(b)
        b.label = W.Label(b, "", 11, W.white)
        b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.state, b.frame = 0, i == 0 and -3 or 0
        b:SetScript("OnEnter", function()
            b.over = true
            paint(win)
            GameTooltip:SetOwner(b, "ANCHOR_TOP")
            GameTooltip:AddLine(i == 0 and "Parcels" or "Mail", 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function()
            b.over, b.pressed = false, false
            paint(win)
            GameTooltip:Hide()
        end)
        b:HookScript("OnMouseDown", function(_, button)
            b.pressed = button == "LeftButton"
            paint(win)
        end)
        -- Wire: the pane's control i through the game layer's one press path (s6-input round 49, Astra's review of step
        -- 4b), so its release finds the control under the pointer among every parcel and letter button an interface draws,
        -- and theirs find these (ParcelPane::HandlePointerOrMouseEvent 0x00546610, case 3). Changing it changes what the
        -- server sees.
        Parcels.Wire(b, i)
        b:HookScript("OnMouseUp", function()
            b.pressed = false
            paint(win)
        end)
        win.buttons[i] = b
    end
    local elapsedTotal = 0
    win:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + (elapsed or 0)
        if elapsedTotal < 0.2 then return end
        elapsedTotal = 0
        local c = win.view and win.view.contents or {}
        if (c.left or 0) > 0 and not c.leftAcknowledged then advance(win.buttons[0], 6) end
        if (c.right or 0) > 0 and not c.rightAcknowledged then advance(win.buttons[1], 20) end
        paint(win)
    end)
    win:Hide()
    return win
end

function Parcel.update(win)
    for i = 0, 1 do
        local c = win.view.contents
        local count = (i == 0 and c.left or c.right) or 0
        local ack = i == 0 and c.leftAcknowledged or c.rightAcknowledged
        -- A side without a count, or acknowledged, stops blinking where it is (SetParcelSlotData: state 0).
        if count == 0 or ack then win.buttons[i].state = 0 end
    end
    paint(win)
end

C.renderers.ParcelPane = Parcel

-- D-55: the Menu popup (MenuVarietySelectPane), above the micro menu. Its rows are controls 0-9, the popup around them
-- -1. A left press outside it closes it and goes no further, a right press goes by (the model; main.lua carries a press
-- that posts nothing of its own to it); any key closes it and goes on (main.lua's key hook).
-- Wire: MenuVarietySelectPane::HandlePointerOrMouseEvent 0x005BD000 and HandleKeyOrTextEvent 0x005BD3A0: a press on a
-- row goes to its control (0-9), on the popup to -1; changing the indexes changes what the server sees.
local Menu = { look = "MenuPopup" }

function Menu.build(view)
    local L = C.look.MenuPopup
    local rows = view.contents.rows or {}
    local win = L.panel(#rows)
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:EnableMouse(true)
    K.Wire(win, win, -1)
    win.rows = {}
    for i, name in ipairs(rows) do
        local r = CreateFrame("Button", nil, win)
        r.label = W.Label(r, name, 12, W.white)
        L.row(win, r, i)
        r.__dialogParent = win
        K.Wire(win, r, i - 1)
        win.rows[i] = r
    end
    win:Hide()
    return win
end

function Menu.update() end

C.renderers.MenuVarietySelectPane = Menu

-- D-56: the player menu (RightButtonMenuPane) at the press that opened it, as the original's (x - 50, y - 50; s6-modular-b
-- round 10, K5: not at the pointer when it is drawn, which may have moved on by then): the target's name, then
-- Look, Trade, Whisper, Group and Info (controls 0-4; the menu around them -1). A press anywhere else closes it (the
-- model; main.lua's GLOBAL_MOUSE_DOWN): a left press goes on, a right press does not; a key closes it and goes on.
-- Wire: RightButtonMenuPane::HandlePointerOrMouseEvent 0x00554C40 and HandleKeyOrTextEvent 0x00554F90: a press on a row
-- goes to its control (0-4), on the menu to -1; changing the indexes changes what the server sees.
local Player = { look = "PlayerMenu" }

function Player.build(view)
    local L = C.look.PlayerMenu
    local rows = view.contents.rows or {}
    local win = L.panel(#rows)
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:EnableMouse(true)
    K.Wire(win, win, -1)
    win.name = W.Label(win, "", 12, W.gold)
    win.rows = {}
    for i, label in ipairs(rows) do
        local r = CreateFrame("Button", nil, win)
        r.label = W.Label(r, label, 12, W.white)
        L.row(win, r, i)
        K.Wire(win, r, i - 1)
        win.rows[i] = r
    end
    L.place(win)
    win:Hide()
    return win
end

function Player.update(win, view)
    win.name:SetText(view.contents.name or "")
    -- A new target moves the menu, as SetTargetNameAndId with the original's reused pane.
    if win.target ~= view.contents.id then
        win.target = view.contents.id
        win:ClearAllPoints()
        C.look.PlayerMenu.open(win)
    end
end

C.renderers.RightButtonMenuPane = Player

-- D-75: the transfer's animation (TRANSSVR.EPF with TRANSSVR.PAL, 34 frames, one every 100 ms, fading in over its
-- first 3 s: the original's alpha falls from 0.9 by 0.03 a frame). Text without the packs. It takes no input.
-- s6-ui-login (round 8; the owner, 2026-10-04: "the 7.0 loading animation is still playing behind the new map loading
-- box in the modern them when you login"): the login's 03 opens it and the game server's 05 closes it, so an interface
-- with its own loading screen (Modern's, core/entering.lua) shows that in its place: nothing of it is drawn while the
-- loading screen is up. Drawing only: the model's pane opens, plays sample 412, holds UserPane's keys and closes as in
-- every interface (TransferServerDialogPane, PaneDialogs.cs), so nothing sent or timed changes. s6-rules-dialogs (round
-- 38): the menu's 5E opens it over the login screen too, for 5 s unless a 49 or 6A deletes it first (MainMenuPane.cpp).
local Transfer = { look = "Transfer" }

function Transfer.build()
    local win = CreateFrame("Frame", nil, UIParent)
    win:SetFrameStrata("DIALOG")
    win.tex = win:CreateTexture(nil, "ARTWORK")
    win.text = W.Label(win, "", 14, W.gold)
    C.look.Transfer.place(win)
    local elapsedTotal = 0
    win:SetScript("OnUpdate", function(_, elapsed)
        if TK.Entering:IsShown() ~= win.covered then Transfer.paint(win) end -- the loading screen came or went
        elapsedTotal = elapsedTotal + (elapsed or 0)
        if elapsedTotal < 0.1 then return end
        elapsedTotal = 0
        win.alpha = math.max(0, win.alpha - 0.03)
        win.frame = (win.frame + 1) % 34
        Transfer.paint(win)
    end)
    win:Hide()
    return win
end

function Transfer.paint(win)
    win.covered = TK.Entering:IsShown()
    local key, w, h = Art("TRANSSVR.EPF", win.frame, "TRANSSVR.PAL")
    if key then
        win.tex:SetTexture(key)
        win.tex:SetSize(w, h)
        -- s6-interface-7x-b (round 7): a look that puts each frame where its pane draws it (7.x's: the texture at its crop's
        -- place in the frame, L.Transfer.frame). Drawing only.
        if C.look.Transfer.frame then C.look.Transfer.frame(win, key) end
        win.tex:SetVertexColor(1, 1, 1, 1 - win.alpha)
        win.tex:SetShown(not win.covered)
        win.text:SetText("")
    else
        win.tex:Hide()
        win.text:SetText(win.covered and "" or "Moving to another server...")
        win.text:SetAlpha(1 - win.alpha)
    end
end

function Transfer.update(win)
    if not win.opened then return end
    win.frame, win.alpha = 0, 0.9
    Transfer.paint(win)
end

C.renderers.TransferServerDialogPane = Transfer

-- D-60: the targeting options (TargetOptionDialog): ARROW (2) and SHIFT+ARROW (3), each with its USER (part 0x40) and
-- MONSTER (0x41) switch, which the model toggles on the press; OK (1).
-- Wire: TargetOptionDialog::OnControlCommand 0x005424B0 by these indexes and parts; changing them changes what the
-- server sees.
local Target = { look = "Target" }

function Target.build()
    local L = C.look.Target
    local win = K.Window(L.width, L.height, "Target")
    win.switches = {}
    for row = 1, 2 do
        win.switches[row] = {}
        for part = 0, 1 do
            local b = W.Button(win, "", L.switch, L.buttonHeight)
            K.Wire(win, b, row + 1, nil, 0x40 + part)
            win.switches[row][part] = b
        end
    end
    win.ok = K.Button(win, 1, "OK", L.button)
    L.place(win)
    return win
end

function Target.update(win, view)
    local rows = view.contents.rows or {}
    for row = 1, 2 do
        for part = 0, 1 do
            local on = rows[row] and rows[row][part + 1]
            win.switches[row][part]:SetText((part == 0 and "USER " or "MONSTER ") .. (on and "ON" or "OFF"))
        end
    end
    -- s6-interface-7x (round 1): what a look draws of its own (7.x's: the switches' ONOFFBUT pictures); drawing only
    if C.look.Target.fill then C.look.Target.fill(win, rows) end
end

C.renderers.TargetOptionDialog = Target
