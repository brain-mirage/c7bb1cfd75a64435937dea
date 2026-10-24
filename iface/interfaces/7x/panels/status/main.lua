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
-- s6-ui-core (round 85): the XML twin's scripts; the panes, their pictures, fields, rows and places are main.xml's
-- (core/xml.md).

local C = TK.GetComponent("7x.status")
local H = __tk
local S = require("interfaces.7x.skin")
local Screen = require("interfaces.screen")
local Hud = require("interfaces.7x.hud")
local E = require("interfaces.7x.elements")
local Tips = TK.Game.Tips

local L = TK.Xml.Data("main.xml")

--- C's integer division (truncated toward zero), as the panes centre by it.
local function idiv(a, b)
    local q = a / b
    return q >= 0 and math.floor(q) or math.ceil(q)
end

--- A text drawn as DrawTextInRect draws it, its line's top at top (our font's glyphs a pixel lower, as X.Text's).
local function textAt(fs, f, s, x, top, colour)
    S.PenText(fs, f, s, x, top + 12, colour)
end

-- ----- the name plate -----

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
    local _, _, _, lineA, lineB = H:GetSheet()
    local values = { name = name, lineA = lineA, lineB = lineB }
    local first = 1
    for _, field in ipairs(L.NAMEPLATE) do
        if field.key then
            centred(f, first, values[field.key] or "", field.l, field.t, field.r, field.bold)
            first = first + (field.bold and 3 or 2)
        else
            local digits = string.format("%d", math.max(0, math.floor(level or 0)))
            f.level = S.Number(f, digits, field.variant, field.l + idiv(field.w - field.digit * #digits, 2), field.t, f.level)
        end
    end
end

-- ----- the vitals -----

local function buildVitals(f)
    f.rows = {}
    for _, row in ipairs(L.ROWS) do
        f.rows[row.key] = { bar = {}, commas = {} }
    end
end

--- A number in "%10u" at its row's top: each digit at its place, the commas between the groups.
local function grouped(f, parts, value, top, variant)
    local s = string.format("%10d", math.max(0, math.floor(value or 0)))
    -- s6-ui-core (round 105, T11 step 9): drawn again only when the number changed (each vitals event drew every row's
    -- digits again, ten calls into C# a digit). Drawing only.
    if parts.drawn == s then return end
    parts.drawn = s
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
                t:SetPoint("TOPLEFT", f, "TOPLEFT", L.PLACES[i] + ox, -(top + oy))
                t:Show()
            end
        end
    end
    local digits = #(s:gsub(" ", ""))
    local commas = L.COMMAS
    for i, c in ipairs(commas) do
        if digits > c.after then
            parts.commas[i] = S.Picture(f, parts.commas[i], commas.file, 0, commas.palette, c.x, top + commas.down, "ARTWORK")
        elseif parts.commas[i] then
            parts.commas[i]:Hide()
        end
    end
end

--- MulDiv(120, cur, max), rounded; the whole 120 from max on; nothing for max 0 (UserStatusPane2::OnPaint).
local function barWidth(cur, max)
    local length = L.BAR.length
    if not max or max <= 0 then return 0 end
    if cur >= max then return length end
    return math.floor(length * cur / max + 0.5)
end

local function showVitals(f)
    local _, hp, hpMax, mp, mpMax = H:GetUnitVitals("player")
    local _, pct = H:GetPlayerXP()
    local length = L.BAR.length
    local values = {
        hp = { hp, barWidth(hp or 0, hpMax) },
        mp = { mp, barWidth(mp or 0, mpMax) },
        gold = { H:GetMoney() },
        -- the experience bar is the percentage's, MulDiv(120, pct, 100), not clamped
        exp = { H:GetExperience(), math.floor(length * (pct or 0) / 100 + 0.5) },
    }
    for _, row in ipairs(L.ROWS) do
        local parts, v = f.rows[row.key], values[row.key]
        if row.bar and parts.barDrawn ~= v[2] then -- round 105: the bar too only when its width changed
            parts.barDrawn = v[2]
            S.Bar(f, parts.bar, row.bar, L.BAR.right, row.barTop, v[2])
        end
        grouped(f, parts, v[1], row.top, row.variant)
    end
    local known, _, _, x, y = H:GetLocation()
    local p = L.POSITION
    f.x = S.Number(f, known and string.format("%03d", math.max(0, x)) or "", p.variant, p.x, p.top, f.x)
    f.y = S.Number(f, known and string.format("%03d", math.max(0, y)) or "", p.variant, p.y, p.top, f.y)
end

-- ----- the panes -----

local SHOW = { nameplate = showNamePlate, vitals = showVitals }

-- the scripts main.xml names
local scripts = {}

function scripts.Own(f) C:Own(f) end

function scripts.BuildVitals(f) buildVitals(f) end

function scripts.Show(f) TK.SafeCall(SHOW[f.pane], f) end

-- 4a UserStatusPane::HandlePointerOrMouseEvent (0x005B8A10): fields 0/4/12/13, event 4 only, 5000 ms.
-- Other presses fall through. SimpleHelpPane consumes the closing press: changing this changes what the server sees.
-- The same 4a function declines every other event, including right release. Leave that host path alone:
-- the paired normal-help gesture includes 0x11; capturing its release to silence it would change the server's view.
-- Tips.ForPress owns the same single-right check and lifetime; no bow test is added.
function scripts.HelpPress(help, button, double)
    local life = Tips.ForPress(button, double)
    if life then Hud.HelpLine.Show(help:GetParent(), H:OriginalString(help.help), life) end
end

--- The pane's edit-mode place ("7x.<id>"), at its top left.
function scripts.Register(f)
    local key = f.pane
    local label
    for _, pane in ipairs(L.PANES) do if pane.key == key then label = pane.label end end
    C.entries[key] = TK.EditMode:Register(f, "7x." .. key, label, { "TOPLEFT", "TOPLEFT", 0, 0 }, "7x." .. key,
        function() return C:DB()[key].enabled == true end)
end

function C:Refresh()
    for _, pane in ipairs(L.PANES) do
        local f = self.frames and self.frames[pane.key]
        if f and f:IsShown() then TK.SafeCall(SHOW[pane.key], f) end
    end
end

function C:OnEnable()
    self.frames, self.entries = {}, {}
    local ui = TK.Xml.Load("main.xml", { scripts = scripts, elements = E })
    for _, pane in ipairs(L.PANES) do self.frames[pane.key] = ui[pane.key] end
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
    self.frames.vitals:SetUpdateWhen("position") -- s6-ui-core (round 101, T11 step 3): its due frames when the place changed
end

--- At the original's places on the scaled 7.x screen (unless moved), at the screen's scale times their own; in the game
--- only.
function C:Layout()
    if not self.frames then return end
    local db = self:DB()
    for _, pane in ipairs(L.PANES) do
        local d = db[pane.key]
        Screen.Place(self.entries[pane.key], 1024, 768, pane.x, pane.y, d.scale)
        self.frames[pane.key]:SetShown(TK.GameState:InWorld() and d.enabled == true)
    end
    TK.EditMode:UpdateMovers()
end

function C:ApplySettings() self:Layout() end

Screen.Follow(C, "Layout")
