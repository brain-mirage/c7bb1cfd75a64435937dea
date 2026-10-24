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
-- s6-ui-core (round 85): the XML twin's scripts; the pane, its fields' places, pictures, digit rows and help lines are
-- main.xml's (core/xml.md).

local C = TK.GetComponent("5x.status")
local H = __tk
local S = require("interfaces.5x.skin")
local Screen = require("interfaces.screen")
local Help = require("interfaces.5x.help") -- s6-interface-5x-b
local E = require("interfaces.5x.elements")

local L = TK.Xml.Data("main.xml")

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
    for i, p in ipairs({ { L.BARS.empty, l, backW, false }, { full, r - fillW, fillW, true } }) do
        local tex = part[i]
        local key, tw, th = S.Image(L.BARS.file, p[1])
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
    local f = TK.Xml.Load("main.xml", { elements = E }).frame
    self:Own(f)
    self.frame, self.shown = f, {}
    self.entry = Screen.Register(f, "5x.status", "5.x Status", function() return self:DB().enabled == true end)
    -- the values change with the server's packets; drawn again only when one did. s6-ui-core (round 101, T11 step 3):
    -- called only when the player's own values or the place changed (values()'s sources; round 105, T11 step 9: not
    -- the whole world's, which changes each time another unit moves)
    f:SetScript("OnUpdate", function() self:Refresh() end)
    f:SetUpdateWhen("player", "position")
    Help.OnRightPress(f, C.HelpAt) -- s6-interface-5x-b
end

--- The help line for a press at (x, y) of the pane, or nil off the fields.
function C.HelpAt(x, y)
    for _, field in ipairs(L.HELP_FIELDS) do
        local r = field.rect
        if x >= r[1] and x < r[3] and y >= r[2] and y < r[4] then
            local lines = {}
            for _, id in ipairs(type(field.lines) == "table" and field.lines or { field.lines }) do
                lines[#lines + 1] = Help.String(id)
            end
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
    local function centred(tex, art, n)
        local l, t, r, b = table.unpack(art.rect)
        local key, w, h
        if n >= 0 then key, w, h = S.Image(art.file, n, art.palette) end
        if not key then return tex:Hide() end
        S.Picture(f, tex, art.file, n, art.palette, math.floor((l + r) / 2) - math.floor(w / 2), math.floor((t + b) / 2) - math.floor(h / 2))
    end
    centred(f.nation, L.NATION, nation)
    centred(f.totem, L.TOTEM, totem)
    -- the status icon's picture (OldUserStatusPane::OnPaint, UserStatusPane.cpp:2020-2026: icon 0 the frame main.xml names)
    local P = L.PATH
    if icon >= 0 then S.Picture(f, f.path, P.file, icon == 0 and P.peasant or icon - 1, P.palette, P.x, P.y) else f.path:Hide() end
    -- the numbers by main.xml's DIGITS, the bars drawn before vita's and mana's (the digits over them)
    local text = { level = level, might = might, grace = grace, will = will, hp = hp, mp = mp, ep = ep, gold = gold }
    for i, d in ipairs(L.DIGITS) do
        if d.field == "hp" then
            local B = L.BARS
            bar(f, f.hpBar, B[1].full, B[1].rect[1], B[1].rect[2], B[1].rect[3], B[1].rect[4], hp, hpMax)
            bar(f, f.mpBar, B[2].full, B[2].rect[1], B[2].rect[2], B[2].rect[3], B[2].rect[4], mp, mpMax)
        end
        local s = d.field == "place" and string.format(d.format, x, y) or string.format(d.format, text[d.field])
        digits(f, i, s, d.row, d.x, d.y)
    end
end

--- At 5.33's place on the scaled 5.x screen unless moved, at the screen's scale times its own; in the game only.
function C:ApplySettings() Screen.PlacePanel(self, S.WIDTH, S.HEIGHT, L.PLACE[1], L.PLACE[2]) end

Screen.Follow(C, "ApplySettings")
