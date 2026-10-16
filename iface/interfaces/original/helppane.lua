-- s6-devtools (round 5; the interface separation's step 5: docs/development/interface-separation.md 4.4, its finding W9,
-- open question 49): the original client's help line, SimpleHelpPane (constructor 0x004C6F90, ui/HelpPane.cpp; 5.33's
-- 0x00441690 is the same code), for any interface that shows one: a right press on a pane that has one (the clock, the
-- looks' buttons, the status fields) shows a short text near the pointer for a while, one at a time.
-- require("interfaces.original.helppane")(ctx) gives an interface its own: ctx = { skin = its skin (the palette's fields,
-- Text and TextWidth), screen = { width, height } (its fixed game screen, fitted as interfaces/screen.lua fits it) }.
--
-- Moved from 7.x's (interfaces/7x/hud.lua: Hud.Help and Hud.PlaceBox, s6-interface-7x-b's rounds 5-7), which W9 settled
-- from 4a: a press while it shows is used up, and it closes at a move, a key-down, a release or a wheel turn. 5.x's own
-- (interfaces/5x/help.lua) closed at a key-down only. One difference from 7.x's, toward 4a: the box is kept on the
-- interface's screen (4a's ScreenPane), not on the whole window, so it never sits on the letterbox's bars.
-- Drawing only, except the press it uses up and the inputs it closes at (WIRE, in buildTip).

local U = TK.Util
local P = require("interfaces.original.palette")
local Screen = require("interfaces.screen")

-- The one box shown (4a keeps one: Singleton<SimpleHelpPane>; a new one deletes the old), whichever interface shows it.
local tip

local function buildTip()
    local f = CreateFrame("Frame", "TKOriginalHelp", UIParent)
    f:SetFrameStrata("TOOLTIP")
    -- The box is colour 1 framed in 0x80 (OnPaint 0x004C7310's fill and DrawRectFrame). 4a composes the
    -- pane once at alpha 0.2 (constructor 0x004C6F90, Pane mode 2), keeping 6 of 32 parts of the scene.
    -- We use that same 26/32 opacity. Host limitation: SetAlpha uses a CanvasGroup (UIFrame.cs), which fades
    -- each graphic separately, so the fill shows through overlapping text and edges; it does not compose
    -- the pane as one picture as 4a does. Unity also blends in linear space rather than screen pixel values.
    -- The fill uses BARAM.PAL's colour 1, as the skins' other colours (4a: FillRgb565RectCallback).
    f:SetAlpha(26 / 32)
    f.fill = P.Fill(f:CreateTexture(nil, "BACKGROUND"), 1)
    f.fill:SetAllPoints(f)
    -- the frame's four 1-pixel edges: top, bottom (a row each), left, right (a column each)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT", true },
                         { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
        local t = P.Fill(f:CreateTexture(nil, "BORDER"), P.TEXT)
        t:SetPoint(e[1], f, e[1], 0, 0)
        t:SetPoint(e[2], f, e[2], 0, 0)
        if e[3] then t:SetWidth(1) else t:SetHeight(1) end
    end
    f.lines = {}
    -- s6-interface-7x-b (round 5; the separation plan's W9): a press anywhere while it shows only closes it, the press
    -- used up: a catcher over the screen under the box. WIRE: 4a's SimpleHelpPane::HandlePointerOrMouseEvent (0x004C7450,
    -- HelpPane.cpp:339-349) returns true for a left or right press wherever the pointer is (no hit test), so the map
    -- never gets that press and sends nothing for it (a click, a walk, a look); letting the press through changes what
    -- the server sees.
    f.catcher = CreateFrame("Frame", "TKOriginalHelpCatcher", UIParent)
    f.catcher:SetFrameStrata("DIALOG")
    f.catcher:SetFrameLevel(199)
    f.catcher:SetAllPoints(UIParent)
    f.catcher:EnableMouse(true)
    f.catcher:SetScript("OnMouseDown", function() f:Hide() end)
    f.catcher:Hide()
    f:SetScript("OnHide", function() f.catcher:Hide() end)
    f:Hide()
    -- it goes at its time, or at the pointer's next move (OnTimer 0x004C7440, HandlePointerOrMouseEvent 0x004C7450)
    f:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        if GetTime() >= self.untilTime or x ~= self.cursorX or y ~= self.cursorY then self:Hide() end
    end)
    -- s6-interface-7x-b (round 6, the head's review of round 5): and at every other input 4a's goes at, each heard in its
    -- place among the inputs, before it goes where it goes, and taken from nothing (only a press is used up, above). 4a
    -- offers every event to the newest pane first, the tip (EventDispatcher::DispatchEvent 0x004A7130), so it goes at:
    -- - any key-down, its repeats included (types 8 and 10: HandleKeyOrTextEvent 0x004C74A0 deletes it and returns false;
    --   the tip watches the keys, SetWatchesKeys). Not a key-up: EventMan::HandleKeyUp (0x004A98A0) never dispatches its
    --   type 9, so a key let go leaves the tip up;
    -- - any release, left or right: EventMan dispatches each release (types 3 and 6) and then a move (type 0) at the same
    --   point (PostLeftButtonUpEvent 0x004A9260, PostRightButtonUpEvent 0x004A94A0), and the move starts the tip's 0 ms
    --   timer. So the tip a right press shows (the look's buttons, the clock, UserLookPane.cpp:703-716) lasts while that
    --   button is held and goes at its release;
    -- - any wheel turn (type 7, then a move: PostMouseWheelEvent 0x004A95A0).
    -- WIRE: each of these leaves 4a without a tip, so the next press goes to what is under it (the look's Trade sends
    -- 4A 00 and the id, the map walks); a tip kept here would use that press up. Not hiding at one of them, hiding at a
    -- key-up, or taking the key, the release or the turn, changes what the server sees.
    local function gone() if f:IsShown() then f:Hide() end end
    f:SetWatchesKeys(true)
    TK.On("GLOBAL_KEY_DOWN", gone)
    TK.On("GLOBAL_MOUSE_UP", gone)
    TK.On("GLOBAL_MOUSE_WHEEL", gone)
    return f
end

return function(ctx)
    local S = ctx.skin
    local SW, SH = ctx.screen.width, ctx.screen.height
    local Help = {}

    --- The pointer in a frame's own units from its top left (x right, y down), as 4a's panes take a press's point.
    function Help.PointIn(f)
        local l, b, _, h = U.RootRect(f)
        if not l then return 0, 0 end
        local k = f:GetEffectiveScale()
        local x, y = U.CursorRoot()
        return (x - l) / k, (b + h - y) / k
    end

    --- A help box of w x h for owner's press at the pointer, placed as 4a's SimpleHelpPane and ItemHelpPane place theirs
    --- (HelpPane.cpp: their constructors): centred on the press, then moved into owner's rectangle and onto the screen
    --- (moved, never resized), in the sheet's units. An optional drawing scale keeps content-sized sheets readable
    --- below native resolution: convert the owner's rectangle/pointer to sheet units before the same 4a placement.
    --- Without a scale the sheet uses the owner's units, as before. Drawing only.
    function Help.PlaceBox(box, owner, w, h, scale, point)
        local ownerScale = owner:GetEffectiveScale()
        local k = scale or ownerScale
        local ratio = ownerScale / k
        local ow, oh = owner:GetWidth() * ratio, owner:GetHeight() * ratio
        local px, py = Help.PointIn(owner)
        if point then px, py = point[1], point[2] end
        px, py = px * ratio, py * ratio
        local l, t = math.floor(px) - math.floor(w / 2), math.floor(py) - math.floor(h / 2)
        -- into the owner's rectangle: its left (else its right), its top (else its bottom)
        if l < 0 then l = 0 elseif l + w > ow then l = ow - w end
        if t < 0 then t = 0 elseif t + h > oh then t = oh - h end
        -- onto the screen (4a's ScreenPane: the interface's screen where it is fitted in the window), in owner's units
        local rl, rb, _, rh = U.RootRect(owner)
        -- 5.33's pane origins are whole native pixels (constructor 0x00441690); retain that rounding after scaling.
        if ctx.roundOwner then
            rl = math.floor(rl / ownerScale) * ownerScale
            rb = GetScreenHeight() - math.floor((GetScreenHeight() - (rb + rh)) / ownerScale) * ownerScale - rh
        end
        local sl, st = rl / k + l, (GetScreenHeight() - (rb + rh)) / k + t
        local s, left, top = Screen.Fit(SW, SH)
        local x0, y0 = left / k, top / k
        local x1, y1 = (left + SW * s) / k, (top + SH * s) / k
        if sl < x0 then l = l + (x0 - sl) elseif sl + w >= x1 then l = l - (sl + w - x1) end
        if st < y0 then t = t + (y0 - st) elseif st + h >= y1 then t = t - (st + h - y1) end
        box:SetScale(k)
        box:SetSize(w, h)
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", UIParent, "TOPLEFT", rl / k + l, -((GetScreenHeight() - (rb + rh)) / k + t))
    end

    --- 4a's SimpleHelpPane for owner's press at the pointer: text's lines (split at CR, LF and tab) in 0x8F with their pen
    --- at (5, 17 + 13 n), in the skin's font; the box as wide as the widest line + 10 and 13 a line + 9 high, centred on
    --- the press, then moved into owner's rectangle and onto the screen (Help.PlaceBox); for ms milliseconds (5000 by
    --- default, the clock's and 5.33's panes'). Shown in owner's units, as 4a draws it in the owner's coordinates. While
    --- it shows, the next press anywhere only closes it (WIRE: buildTip's catcher); a move, a key-down, a release or a
    --- wheel turn closes it and goes on (WIRE: buildTip's listeners), so a right press's tip lasts while that button is
    --- held.
    function Help.Show(owner, text, ms, point)
        -- WIRE (SimpleHelpPane's constructor 0x004C6F90; s6-interface-7x-b's note, its round 8): an empty text is still
        -- a box, one empty line, 10 x 22, and its catcher uses up the next press as any tip's. Shown nothing instead, that
        -- press would reach what is under it (the look's Trade sends 4A 00). Changing it changes what the server sees.
        text = text or ""
        tip = tip or buildTip()
        local lines = {}
        for line in (text .. "\n"):gmatch("([^\r\n\t]*)[\r\n\t]") do lines[#lines + 1] = line end
        local widest = -1
        for _, line in ipairs(lines) do widest = math.max(widest, S.TextWidth(line) or 0) end
        Help.PlaceBox(tip, owner, widest + 10, 13 * #lines + 9, nil, point)
        for i, line in ipairs(lines) do
            local fs = tip.lines[i] or tip:CreateFontString(nil, "OVERLAY")
            tip.lines[i] = fs
            -- the pen at (5, 17 + 13 (i - 1)): font 0's line top 12 above it, the glyphs one pixel lower
            S.Text(fs, P.WHITE)
            fs:SetWordWrap(false)
            fs:SetJustifyH("LEFT")
            fs:SetText(line)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", tip, "TOPLEFT", 5, -(17 + 13 * (i - 1) - 12 + 1))
            fs:Show()
        end
        for i = #lines + 1, #tip.lines do tip.lines[i]:Hide() end
        tip.untilTime = GetTime() + (ms or 5000) / 1000
        tip.cursorX, tip.cursorY = GetCursorPosition()
        tip:Show()
        -- WIRE: EventDispatcher::DispatchEvent 0x004A7130 offers the newest pane first, also after a replacement.
        -- The server-text pane and local sheet have different input rules; changing their order changes game input.
        TK.Game.ItemHelp.Raise(tip)
        tip.catcher:Show()
    end

    return Help
end
