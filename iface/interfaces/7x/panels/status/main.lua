-- s6-modular-g (interfaces, phase 5, round 14): 7.x's status panes, each a panel of its own (its switch, Layout tab and
-- edit-mode place), drawn in the frame layer at the original's places on the 7.x screen:
--   the name plate  UserStatusPane (OnPaint 0x005B8C70's EPF branch) at (826, 16), 171 x 42: USERSTAT.EPF frame 0 in
--                   ITEMINV.PAL; the name centred in (20, 3)-(96, 17), shadowed 0x80 a pixel right and down, then 0x8F twice a
--                   pixel apart; the level in 9X11FONT's digits (variant 1) centred in (121, 4)-(170, 17) by 10 pixels a digit
--                   (they advance 9); 0x39's lines A and B centred in (0, 26)-(102, 40) and (106, 26)-(170, 40), shadowed
--   the vitals      UserStatusPane2 (OnPaint 0x005BAF80) at (881, 659), 126 x 94, over the backdrop: the vita, mana and
--                   experience bars (BAR.EPF in BAR.PAL, right-anchored at 123, MulDiv(120, cur, max) long) and their
--                   numbers, the gold, all "%10u" in 9X11FONT's digits (variant 2, the gold's 0) with COMMA.EPF between
--                   the groups; the position's x and y "%03u" (variant 1)
-- The digits are drawn in BARAM.PAL (GrafPort's current palette: DrawNumberGlyphString 0x005BA020 blits with none of its
-- own). Four fields on the name plate open 4a's SimpleHelpPane on a right press; the vitals remain drawing only.

local C = TK.GetComponent("7x.status")
local H = __tk
local S = require("interfaces.7x.skin")
local Screen = require("interfaces.screen")
local Hud = require("interfaces.7x.hud")

-- The panes: their settings' key and panel id (their place is "7x.<id>"), frame name, label and place on the screen.
local PANES = {
    { key = "nameplate", name = "TK7xNamePlate", label = "7.x Name Plate", x = 826, y = 16, w = 171, h = 42 },
    { key = "vitals", name = "TK7xVitals", label = "7.x Vitals", x = 881, y = 659, w = 126, h = 94 },
}

--- C's integer division (truncated toward zero), as the panes centre by it.
local function idiv(a, b)
    local q = a / b
    return q >= 0 and math.floor(q) or math.ceil(q)
end

--- A font string of a frame, hidden until drawn.
local function text(f)
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:Hide()
    return fs
end

--- A text drawn as DrawTextInRect draws it, its line's top at top (our font's glyphs a pixel lower, as X.Text's).
local function textAt(fs, f, s, x, top, colour)
    S.PenText(fs, f, s, x, top + 12, colour)
end

-- ----- the name plate -----

local function buildNamePlate(f)
    f.back = S.Picture(f, nil, "USERSTAT.EPF", 0, "ITEMINV.PAL", 0, 0, "BACKGROUND")
    f.texts = {}
    for i = 1, 7 do f.texts[i] = text(f) end
    -- 4a UserStatusPane::HandlePointerOrMouseEvent (0x005B8A10): fields 0/4/12/13, event 4 only, 5000 ms.
    -- Other presses fall through. SimpleHelpPane consumes the closing press: changing this changes what the server sees.
    -- The same 4a function declines every other event, including right release. Leave that host path alone:
    -- the paired normal-help gesture includes 0x11; capturing its release to silence it would change the server's view.
    local fields = { {20, 3, 96, 17, 185}, {121, 4, 170, 17, 186},
                     {0, 26, 102, 40, 188}, {106, 26, 170, 40, 187} }
    for i, field in ipairs(fields) do
        local help = CreateFrame("Frame", "TK7xStatusHelp" .. i, f)
        help:SetPoint("TOPLEFT", f, "TOPLEFT", field[1], -field[2])
        help:SetSize(field[3] - field[1], field[4] - field[2])
        help:SetClaimButtons("RightButton")
        help:SetPassesDoubles(true)
        help:SetScript("OnMouseDown", function(_, button, double)
            if button == "RightButton" and not double then Hud.HelpLine.Show(f, H:OriginalString(field[5]), 5000) end
        end)
    end
end

--- A field's text centred in (l, t)-(r, ...): its shadow 0x80 at (x + 1, t + 1), its face 0x8F at (x, t), and again a
--- pixel left when bold (the name). Uses texts[first..].
local function centred(f, first, s, l, t, r, bold)
    local w = S.TextWidth(s) or 0
    local x = l + idiv(r - l - w, 2)
    textAt(f.texts[first], f, s, x + 1, t + 1, S.TEXT)
    textAt(f.texts[first + 1], f, s, x, t, 0x8F)
    if bold then textAt(f.texts[first + 2], f, s, x - 1, t, 0x8F) end
end

local function showNamePlate(f)
    for _, fs in ipairs(f.texts) do fs:Hide() end
    local _, name, level = H:GetUnitInfo("player")
    centred(f, 1, name or "", 20, 3, 96, true)
    local _, _, _, lineA, lineB = H:GetSheet()
    centred(f, 4, lineA or "", 0, 26, 102)
    centred(f, 6, lineB or "", 106, 26, 170)
    local digits = string.format("%d", math.max(0, math.floor(level or 0)))
    f.level = S.Number(f, digits, 1, 121 + idiv(49 - 10 * #digits, 2), 4, f.level)
end

-- ----- the vitals -----

-- The rows: their bar's frames (middle, left cap, right cap), their numbers' top and digit variant.
local ROWS = {
    { key = "hp", bar = { 0, 1, 2 }, top = 2, variant = 2, barTop = 0 },
    { key = "mp", bar = { 3, 4, 5 }, top = 21, variant = 2, barTop = 19 },
    { key = "gold", top = 40, variant = 0 },
    { key = "exp", bar = { 6, 7, 8 }, top = 59, variant = 2, barTop = 57 },
}

-- "%10u"'s ten places: the leading digit at x 13, then three groups of three from x 26, 57 and 88, 9 apart; a comma
-- (COMMA.EPF in COMMA.PAL) 4 left of a group and 6 down, before each group a digit precedes.
local PLACES = { 13, 26, 35, 44, 57, 66, 75, 88, 97, 106 }
local COMMAS = { { 22, 9 }, { 53, 6 }, { 84, 3 } } -- { x, the digits it needs after it }

local function buildVitals(f)
    f.rows = {}
    for _, row in ipairs(ROWS) do
        f.rows[row.key] = { bar = {}, commas = {} }
    end
end

--- A number in "%10u" at its row's top: each digit at its place, the commas between the groups.
local function grouped(f, parts, value, top, variant)
    local s = string.format("%10d", math.max(0, math.floor(value or 0)))
    parts.digits = parts.digits or {}
    for _, t in ipairs(parts.digits) do t:Hide() end
    local n = 0
    for i = 1, 10 do
        local d = tonumber(s:sub(i, i))
        if d then
            n = n + 1
            local key, w, h, ox, oy = S.Digit(d, variant)
            if key then
                local t = parts.digits[n] or f:CreateTexture(nil, "ARTWORK")
                parts.digits[n] = t
                t:SetTexture(key)
                t:SetSize(w, h)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", f, "TOPLEFT", PLACES[i] + ox, -(top + oy))
                t:Show()
            end
        end
    end
    local digits = #(s:gsub(" ", ""))
    for i, c in ipairs(COMMAS) do
        if digits > c[2] then
            parts.commas[i] = S.Picture(f, parts.commas[i], "COMMA.EPF", 0, "COMMA.PAL", c[1], top + 6, "ARTWORK")
        elseif parts.commas[i] then
            parts.commas[i]:Hide()
        end
    end
end

--- MulDiv(120, cur, max), rounded; the whole 120 from max on; nothing for max 0 (UserStatusPane2::OnPaint).
local function barWidth(cur, max)
    if not max or max <= 0 then return 0 end
    if cur >= max then return 120 end
    return math.floor(120 * cur / max + 0.5)
end

local function showVitals(f)
    local _, hp, hpMax, mp, mpMax = H:GetUnitVitals("player")
    local _, pct = H:GetPlayerXP()
    local values = {
        hp = { hp, barWidth(hp or 0, hpMax) },
        mp = { mp, barWidth(mp or 0, mpMax) },
        gold = { H:GetMoney() },
        -- the experience bar is the percentage's, MulDiv(120, pct, 100), not clamped
        exp = { H:GetExperience(), math.floor(120 * (pct or 0) / 100 + 0.5) },
    }
    for _, row in ipairs(ROWS) do
        local parts, v = f.rows[row.key], values[row.key]
        if row.bar then S.Bar(f, parts.bar, row.bar, 123, row.barTop, v[2]) end
        grouped(f, parts, v[1], row.top, row.variant)
    end
    local known, _, _, x, y = H:GetLocation()
    f.x = S.Number(f, known and string.format("%03d", math.max(0, x)) or "", 1, 31, 79, f.x)
    f.y = S.Number(f, known and string.format("%03d", math.max(0, y)) or "", 1, 89, 79, f.y)
end

-- ----- the panes -----

local BUILD = { nameplate = buildNamePlate, vitals = buildVitals }
local SHOW = { nameplate = showNamePlate, vitals = showVitals }

function C:Refresh()
    for _, pane in ipairs(PANES) do
        local f = self.frames and self.frames[pane.key]
        if f and f:IsShown() then TK.SafeCall(SHOW[pane.key], f) end
    end
end

function C:OnEnable()
    self.frames, self.entries = {}, {}
    for _, pane in ipairs(PANES) do
        local f = CreateFrame("Frame", pane.name, UIParent)
        f:SetFrameStrata("LOW")
        f:SetFrameLevel(10) -- the frame layer, over the backdrop
        f:SetSize(pane.w, pane.h)
        f:Hide()
        self:Own(f)
        BUILD[pane.key](f)
        f:SetScript("OnShow", function() TK.SafeCall(SHOW[pane.key], f) end)
        self.frames[pane.key] = f
        local key = pane.key
        self.entries[key] = TK.EditMode:Register(f, "7x." .. key, pane.label, { "TOPLEFT", "TOPLEFT", 0, 0 }, "7x." .. key,
            function() return self:DB()[key].enabled == true end)
    end
    local events = CreateFrame("Frame")
    for _, e in ipairs({ "UNIT_NAME_UPDATE", "UNIT_HEALTH", "UNIT_POWER", "PLAYER_MONEY", "PLAYER_XP_UPDATE",
                         "TK_CHARACTER_SHEET" }) do
        events:RegisterEvent(e)
    end
    events:SetScript("OnEvent", function(_, _, unit) if unit == nil or unit == "player" then self:Refresh() end end)
    -- the position changes with every step (0x04, 0x0B, 0x26): looked at ten times a second while the vitals show
    local last
    self.frames.vitals:SetScript("OnUpdate", TK.Util.Throttled(0.1, function(f)
        local _, _, _, x, y = H:GetLocation()
        local at = tostring(x) .. "," .. tostring(y)
        if at ~= last then
            last = at
            TK.SafeCall(showVitals, f)
        end
    end))
end

--- At the original's places on the scaled 7.x screen (unless moved), at the screen's scale times their own; in the game
--- only.
function C:Layout()
    if not self.frames then return end
    local db = self:DB()
    for _, pane in ipairs(PANES) do
        local d = db[pane.key]
        Screen.Place(self.entries[pane.key], 1024, 768, pane.x, pane.y, d.scale)
        self.frames[pane.key]:SetShown(TK.GameState:InWorld() and d.enabled == true)
    end
    TK.EditMode:UpdateMovers()
end

function C:ApplySettings() self:Layout() end

Screen.Follow(C, "Layout")
