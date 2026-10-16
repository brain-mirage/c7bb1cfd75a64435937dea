-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md): 5.33's status pane,
-- OldUserStatusPane (constructor 0x004E0B60, at (433, 372)-(626, 468) on the 640 x 480 screen), drawn as its paint
-- (UserStatusPane::OnPaint 0x004E14F0) draws it, its fields at GetStatusFieldRect's rectangles (0x004E1E90):
--    0 the name (59, 3)-(131, 15), in white (0x8F)
--    1 the nation (1, 49)-(56, 94), NATION.EPF's picture of it, centred      2 the totem (1, 2)-(56, 47), TOTEM.EPF's, centred
--    3 the status icon (147, 0)-(193, 17), CLASS.EPF (icon - 1; 4 for 0)     4 the level (160, 3), "%3u" in digit row 2
--    5 might (75, 17), 6 grace (163, 17), 7 will (120, 17): "%3u" in digit row 1
--    8 vita and 9 mana (101, 30)-(192, 42) and (101, 43)-(192, 55): BAR.EPF's empty bar (frame 2) from the left as wide as
--      what is missing, its full bar (frame 0, 1 for mana) from the right as wide as what is left (MulDiv), the value
--      "%10u" in digit row 0 over them
--   10 experience (101, 56), "%10u" in row 0     11 gold (101, 69), "%10u" in row 2
--   12 the place on the map (101, 82), "%04u/%04u" in row 2 (the '/' a blank cell, as DrawNumberGlyphString skips it)
-- on USERSTAT.EPF; the pictures in NPAL7.PAL (CLASS.EPF in NPAL5.PAL), the bars and digits in BARAM.PAL (no palette
-- named). The values are the client's (7.5.2's 0x08, 0x04 and the map's position): this pane reads them and sends
-- nothing. A right press on a field shows its help line for 5 s (s6-interface-5x-b: C.HelpAt, interfaces/5x/help.lua).

local C = TK.GetComponent("5x.status")
local H = __tk
local S = require("interfaces.5x.skin")
local Screen = require("interfaces.screen")
local Help = require("interfaces.5x.help") -- s6-interface-5x-b

local PLACE = { 433, 372 }

--- A bar of fields 8 and 9: the empty bar from the field's left as wide as what is missing, the full bar from its right
--- as wide as what is left, each a crop of its picture (the empty one's left part, the full one's right part), on the
--- field's middle row (UserStatusPane::OnPaint's classic branch, 4a ui/UserStatusPane.cpp's twin).
local function bar(f, part, full, l, t, r, b, value, max)
    local w = r - l
    local backW, fillW = w, 0
    if max ~= 0 then
        backW = value < max and S.MulDiv(w, max - value, max) or 0
        fillW = value < max and S.MulDiv(w, value, max) or w
    end
    local mid = math.floor((t + b) / 2)
    for i, p in ipairs({ { 2, l, backW, false }, { full, r - fillW, fillW, true } }) do
        local tex = part[i]
        local key, tw, th = S.Image("BAR.EPF", p[1])
        if key and p[3] > 0 then
            local cw = math.min(p[3], tw)
            tex:SetTexture(key)
            -- the empty bar's left part, the full bar's right part
            if p[4] then tex:SetTexCoord((tw - cw) / tw, 1, 0, 1) else tex:SetTexCoord(0, cw / tw, 0, 1) end
            tex:SetSize(cw, th)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", f, "TOPLEFT", p[2], -(mid - math.floor(th / 2)))
            tex:Show()
        else
            tex:Hide()
        end
    end
end

function C:OnEnable()
    local f = CreateFrame("Frame", "TK5xStatus", UIParent)
    f:SetFrameStrata("LOW")
    f:SetSize(193, 96)
    f.back = S.Picture(f, nil, "USERSTAT.EPF", 0, "NPAL7.PAL", 0, 0, "BACKGROUND")
    f.name = S.Text(f:CreateFontString(nil, "ARTWORK"), S.WHITE)
    f.name:SetWordWrap(false)
    f.name:SetJustifyH("LEFT")
    f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 59, -4)
    f.name:SetWidth(72)
    f.totem, f.nation, f.path = f:CreateTexture(nil, "ARTWORK"), f:CreateTexture(nil, "ARTWORK"), f:CreateTexture(nil, "ARTWORK")
    -- the bars under the digits drawn over them (DrawNumberGlyphString follows the blits)
    f.hpBar = { f:CreateTexture(nil, "BORDER"), f:CreateTexture(nil, "BORDER") }
    f.mpBar = { f:CreateTexture(nil, "BORDER"), f:CreateTexture(nil, "BORDER") }
    f.digits = {}
    f:Hide()
    self:Own(f)
    self.frame, self.shown = f, {}
    self.entry = Screen.Register(f, "5x.status", "5.x Status", function() return self:DB().enabled == true end)
    -- the values change with the server's packets; drawn again only when one did
    f:SetScript("OnUpdate", function() self:Refresh() end)
    Help.OnRightPress(f, C.HelpAt) -- s6-interface-5x-b
end

-- s6-interface-5x-b: the fields' help lines (OldUserStatusPane__HandlePointerOrMouseEvent 0x004E0D80, a right press:
-- the first field holding the press, its rectangle as GetStatusFieldRect gives it, fields 5-7 widened 16 pixels to the
-- left and 8-12 40, over their labels), each 7.5.2's line for 5.33's (interfaces/5x/help.lua): the name 185, the
-- nation 184, the totem 183, the level and path 186 and 187 (5.33's one line 186; field 4 lies inside field 3, so
-- field 3 takes its presses), might 189, grace 191, will 190, vita 192, mana 193, experience 194, gold 195, the place 196.
local HELP_FIELDS = {
    { 59, 3, 131, 15, { 185 } }, { 1, 49, 56, 94, { 184 } }, { 1, 2, 56, 47, { 183 } },
    { 147, 0, 193, 17, { 186, 187 } }, { 160, 3, 190, 15, { 186, 187 } },
    { 59, 17, 102, 29, { 189 } }, { 147, 17, 190, 29, { 191 } }, { 104, 17, 147, 29, { 190 } },
    { 61, 30, 192, 42, { 192 } }, { 61, 43, 192, 55, { 193 } }, { 61, 56, 192, 68, { 194 } },
    { 61, 69, 192, 81, { 195 } }, { 61, 82, 192, 94, { 196 } },
}

--- The help line for a press at (x, y) of the pane, or nil off the fields.
function C.HelpAt(x, y)
    for _, r in ipairs(HELP_FIELDS) do
        if x >= r[1] and x < r[3] and y >= r[2] and y < r[4] then
            local lines = {}
            for _, id in ipairs(r[5]) do lines[#lines + 1] = Help.String(id) end
            return #lines > 0 and table.concat(lines, "\n") or nil
        end
    end
end

--- The pane's values now: { name, nation, totem, icon, level, might, grace, will, hp, hpMax, mp, mpMax, ep, gold, x, y }.
--- The icon is 0x05's byte 9 as OldUserStatusPane keeps it (s6-ui-core round 93: 4 or less, else the last; -1 none yet).
local function values()
    local _, name, level = H:GetUnitInfo("player")
    local _, hp, hpMax, mp, mpMax = H:GetUnitVitals("player")
    local might, will, grace = H:GetPlayerStats()
    local nation, totem, icon = H:GetPlayerOrigin()
    local known, _, _, x, y = H:GetLocation()
    return { name or "", nation or -1, totem or -1, icon or -1, level or 0, might or 0, grace or 0, will or 0,
             hp or 0, hpMax or 0, mp or 0, mpMax or 0, math.floor(H:GetExperience() or 0), math.floor(H:GetMoney() or 0),
             known and x or 0, known and y or 0 }
end

--- A number in 9X11FONT.BIN's digit row at (x, y) of the pane (5.33's "%3u", "%10u", "%04u/%04u": Lua's "%d" alike for
--- the unsigned values these are).
local function digits(f, i, text, row, x, y) f.digits[i] = S.Number(f, text, row, x, y, f.digits[i]) end

function C:Refresh()
    local f, v = self.frame, values()
    local same = true
    for i = 1, #v do
        if self.shown[i] ~= v[i] then same = false break end
    end
    if same then return end
    self.shown = v
    local name, nation, totem, icon, level, might, grace, will, hp, hpMax, mp, mpMax, ep, gold, x, y = table.unpack(v)
    f.name:SetText(name)
    -- the nation's and the totem's pictures centred in their fields ((l + r) / 2 - w / 2, as 5.33's integer halves);
    -- nothing while unknown (-1) or without a picture for it
    local function centred(tex, file, n, l, t, r, b)
        local key, w, h
        if n >= 0 then key, w, h = S.Image(file, n, "NPAL7.PAL") end
        if not key then return tex:Hide() end
        S.Picture(f, tex, file, n, "NPAL7.PAL", math.floor((l + r) / 2) - math.floor(w / 2), math.floor((t + b) / 2) - math.floor(h / 2))
    end
    centred(f.nation, "NATION.EPF", nation, 1, 49, 56, 94)
    centred(f.totem, "TOTEM.EPF", totem, 1, 2, 56, 47)
    -- the status icon's picture at (147, 0) (OldUserStatusPane::OnPaint, UserStatusPane.cpp:2020-2026: icon 0 frame 4)
    if icon >= 0 then S.Picture(f, f.path, "CLASS.EPF", icon == 0 and 4 or icon - 1, "NPAL5.PAL", 147, 0) else f.path:Hide() end
    digits(f, 1, string.format("%3d", level), 2, 160, 3)
    digits(f, 2, string.format("%3d", might), 1, 75, 17)
    digits(f, 3, string.format("%3d", grace), 1, 163, 17)
    digits(f, 4, string.format("%3d", will), 1, 120, 17)
    bar(f, f.hpBar, 0, 101, 30, 192, 42, hp, hpMax)
    bar(f, f.mpBar, 1, 101, 43, 192, 55, mp, mpMax)
    digits(f, 5, string.format("%10d", hp), 0, 101, 30)
    digits(f, 6, string.format("%10d", mp), 0, 101, 43)
    digits(f, 7, string.format("%10d", ep), 0, 101, 56)
    digits(f, 8, string.format("%10d", gold), 2, 101, 69)
    digits(f, 9, string.format("%04d/%04d", x, y), 2, 101, 82)
end

--- At 5.33's place on the scaled 5.x screen unless moved, at the screen's scale times its own; in the game only.
function C:ApplySettings() Screen.PlacePanel(self, S.WIDTH, S.HEIGHT, PLACE[1], PLACE[2]) end

Screen.Follow(C, "ApplySettings")
