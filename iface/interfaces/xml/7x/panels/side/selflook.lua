-- 7.x's self look (side panel tab 0), 4a's SelfLookPane (ui/SelfLookPane.cpp). s6-modular-g's round 14 drew its
-- equipment view in panels/side/main.lua; s6-interface-7x-b (round 5; the owner, 2026-10-05) moved it here and added its
-- other two views, as 4a draws and runs them.
--
-- Three views (m_activeViewMode), each on SELFLOOK.EPF's frame of its number in LOOKICON.PAL (OnPaint 0x00567480):
--   0  the equipment: the 14 worn items in their 48 x 48 slots (GetSlotRect 0x00569ED0: pane slots 7-20), each its
--      whole frame centred and dyed by its colour byte, moved (-2, -2) under the pointer over LOOKICON's frame; the
--      exchange and group switches (STATBUTS.EPF 7 / 2 and 8 / 3, filled 0x8F while 0xFF); the helmet and necklace
--      switches (ONOFFBUT.EPF 0 when 0, else 1); button 2 (filled 0x8F while 0x39's statsToggle is 0xFF)
--   1  the status: 0x39's first two strings (59, 25) / (59, 45), the nation centred on 64 and the spirit on 133 at y 86,
--      0x39's fourth string from its eighth character at (58, 105): each 0x80 there, then 0x25 a pixel up (and left);
--      9X11FONT's digits: might, grace and will centred in 32 pixels at x 24, 83, 142 (set 1), the summary bytes
--      right-aligned to 110, 83, 168 (set 2, signed, a minus being FONTSYMB.EPF 4), the summary u32 and the vita and
--      mana maxima as "%10u" at y 180 (set 0), 200 and 220 (set 2), in groups of three (no commas in this build)
--   2  the legend (7, 15)-(182, 265), 4a's LegendPane (a TextEditPane wrapped at 160), scrolled to its end
-- The arrows: next (169, 268) in views 0 and 1, previous (149, 268) in view 1 and (169, 268) in view 2 (INVENBUT.EPF
-- 7 x state + 6 / 5). The views change by the arrows, Page Up and Page Down (stopping at either end), and the status key
-- S, which cycles 0, 1, 2, 0 (HandleKeyOrTextEvent 0x00568BD0, SelfLookPane.cpp:1067); every 0x39 shows the view an S
-- 0x3E asked for, else view 0 (OnActivate 0x00565890: m_serverRequestedViewMode, then 0), which its tab notice carries.
--
-- WIRE (HandlePointerOrMouseEvent 0x00568CB0, a single left press, event type 1; taken with nothing sent while the bow is
-- drawn, which the rules test): in view 0 only (GetSlotRect gives every control below -1 in views 1 and 2, so a press
-- there sends nothing):
--   a worn slot sends 1F and its code, whether it holds an item or not (SelfLookPane.cpp:1220-1265 call
--     SendTakeOffPacket 0x005B27C0 with no item test): the self look's "takeoff" action on the "selflook" path, run on
--     the press (TK.Game.SelfLook.WornControl; TK-Core ItemRules.TakeOff sends it unless a dialog is alive)
--   the switches send option 8, 2, 14 and 15 on the "selflook" path: 1B 01 08 00 and 1B 01 02 00 (refused while 0x39's
--     state is 0xFF, at most one a second), 1B 01 0E and 1B 01 0F (KeyCommandRules.Option)
--   button 2 takes the press and sends nothing (SelfLookPane.cpp:1196)
-- A single right press on a worn slot (event type 4) shows the item box (interfaces/7x/itembox.lua: 4a's ItemHelpPane,
-- round 7), which then takes every pointer event until a single press closes it, and goes at a key (the key goes on).
-- The necklace switch (49, 221)-(63, 235) lies over the necklace's slot (10, 226)-(58, 274): HitTestSlot (0x0056A300)
-- takes the lower number first, the switch (pane slot 6), so the switches sit above the slots. The S key, the arrows and
-- the views send nothing; S taken here keeps UserPane's RequestLocalPlayerStatus (2D 00) from running, as 4a's pane takes
-- 's' first while it is the active tab (main.lua's StatusKey). Changing any of these changes what the server sees.
-- s6-ui-core (round 85): the XML twin's scripts; the page, its slots', switches' and arrows' places are selflook.xml's
-- (core/xml.md).

local H = __tk
local S = require("interfaces.7x.skin")
local K = require("interfaces.7x.panels.side.kit")
local Elements = require("interfaces.7x.panels.side.elements") -- the kit as layout elements (the twin's own)
local Hud = require("interfaces.7x.hud")
local Look = require("interfaces.7x.panels.side.look")
local ItemBox = require("interfaces.7x.itembox")
local SelfLook = TK.Game.SelfLook

local P = {}

local X = TK.Xml.Data("selflook.xml")

-- The worn items' slots by the server's slot code (selflook.xml's GEAR): { x, y, frame, fx, fy, name }.
local GEAR = {}
for _, g in ipairs(X.GEAR) do GEAR[g.code] = g end

-- The order the slots are made in: the original's (pairs over its table of the slots by code). This table has the same
-- keys in the same order in its constructor, so pairs goes through it in that order (a table's order follows its keys
-- and how they were put in): the slots' controls and pictures are made in the same order, their draw order and the
-- frames' order the same.
local ORDER = { [22] = true, [4] = true, [23] = true, [1] = true, [2] = true, [3] = true, [8] = true, [14] = true,
    [7] = true, [20] = true, [16] = true, [21] = true, [6] = true, [13] = true }

-- The switches (buttons 0, 1, 5 and 6: selflook.xml's SWITCHES)
local SWITCHES = X.SWITCHES

-- the nations' (0-4) and spirits' (0-3) names
local NATIONS, SPIRITS = X.NATIONS, X.SPIRITS

-- The arrows' places by view (GetSlotRect's 4, next, and 3, previous)
local NEXT, BACK = {}, {}
for _, at in ipairs(X.NEXT) do NEXT[at.view] = { at.x, at.y } end
for _, at in ipairs(X.BACK) do BACK[at.view] = { at.x, at.y } end

--- A value as 4a's GetNationId and GetSpiritId give it: the low byte, sign-extended (255 for -1, not known).
local function sbyte(v) v = (v or -1) % 256 return v >= 128 and v - 256 or v end

--- C's integer division (toward zero), as 4a's centring offsets divide.
local function div(a, b) local q = a / b return q >= 0 and math.floor(q) or math.ceil(q) end

local function step(p, view)
    p.view = view
    P.Show(p)
end

-- the scripts selflook.xml names
local scripts = {}

--- The worn slots' controls, made in the original's order (ORDER).
function scripts.Gear(p)
    p.gear = {}
    for code in pairs(ORDER) do
        local g = GEAR[code]
        local b = K.Hit(p, g.x, g.y, g.x + 48, g.y + 48, "TK7xGear" .. code)
        b.code, b.icon = code, p:CreateTexture(nil, "ARTWORK")
        -- WIRE: 1F and the slot's code on the left press, held or empty (the header; the game layer's worn control)
        SelfLook.WornControl(b)
        SelfLook.TakeOff(b, code)
        -- s6-interface-7x-b (round 7): a single right press (type 4: not a double, type 5) on a slot holding an item (its
        -- raw picture number not 0: IconId 0x4000) shows the item box (SelfLookPane.cpp:1139-1183: ItemHelpPane with the
        -- slot's description string, name, value and value flags); on an empty slot it is taken with nothing shown, and
        -- with the bow drawn it is taken with nothing shown (IsBowDrawing). Nothing is sent: the slot takes the right
        -- press either way, as 4a's case 4 returns true.
        SelfLook.WornHelp(b, p, ItemBox, function() return SelfLook.EquipmentForCode(code) end)
        b:SetScript("OnEnter", function()
            p.over = b
            -- the slot's name 1000 ms after the pointer came onto a slot other than the last one (s_lastHoverSlot, never
            -- cleared), where it came, for 5000 ms; leaving the slot does not stop it (OnTimer 0x00569860)
            if p.lastHover ~= code then
                p.lastHover = code
                p.tipAt, p.tipText = GetTime() + 1, g.name
            end
            P.Show(p)
        end)
        b:SetScript("OnLeave", function() if p.over == b then p.over = nil P.Show(p) end end)
        p.gear[code] = b
    end
end

--- The switches' controls, over the slots: HitTestSlot's order (the header).
function scripts.Switches(p)
    p.switches = {}
    for _, def in ipairs(SWITCHES) do
        local r = def.rect
        local b = K.Hit(p, r[1], r[2], r[3], r[4], "TK7xSelfSwitch" .. def.id)
        b:SetFrameLevel(p:GetFrameLevel() + 3) -- over the slots: HitTestSlot's order (the header)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        -- WIRE: the option on the self-look path, on the left press (the header; the game layer's switch control)
        SelfLook.SwitchControl(b, def.option)
        if def.help then
            -- WIRE (s6-interface-7x-b round 6): SelfLookPane::HandlePointerOrMouseEvent (0x00568CB0) shows the help for
            -- type 4 only, so a right double press (type 5) shows none, and none with the bow drawn (round 7: its
            -- IsBowDrawing test comes first); the tip uses up the next press (Hud.HelpLine.Show), so a tip 4a does not
            -- show would take a press 4a sends on
            b:HookScript("OnMouseDown", function(_, button, double)
                if button == "RightButton" and not double and not H:IsBowDrawing() then
                    Hud.HelpLine.Show(p, H:OriginalString(def.help) or "", 5000)
                end
            end)
        end
        p.switches[def.id] = b
    end
end

function scripts.Next(p) step(p, p.view + 1) end

function scripts.Previous(p) step(p, p.view - 1) end

function scripts.Tip(p)
    if p.tipAt and GetTime() >= p.tipAt then
        p.tipAt = nil
        -- none while the item box shows (OnTimer 0x00569860 tests Singleton<ItemHelpPane> first)
        if p.view == 0 and not ItemBox.Shown() then Hud.HelpLine.Show(p, p.tipText, 5000) end
    end
end

function P.Build(parent)
    return TK.Xml.Load("selflook.xml", { scripts = scripts, elements = Elements, parent = parent }).frame
end

--- OnActivate (each 0x39): the view its notice carries (the page an S 0x3E asked for since the previous 0x39, else the
--- equipment: TK-Core GameRules resolves it at the packet, RuleNotice.PanelView).
function P.Activate(p, view)
    p.view = view or 0
    p.legendShown = nil
end

--- Page Up and Page Down: the views back or on, stopping at either end, the key taken (HandleKeyOrTextEvent returns
--- true; nothing sent).
function P.Page(p, delta)
    step(p, math.max(0, math.min(2, p.view + delta)))
    return true
end

--- The status key while this is the active tab: the views cycle 0, 1, 2, 0 (the key taken, nothing sent).
function P.StatusKey(p)
    step(p, (p.view + 1) % 3)
end

--- Three draws of a text: 0x80 at (x, y), then 0x25 at (x2, y - 1) and (x3, y - 1).
local function triple(p, i, text, x, y, x2, x3)
    S.PenText(p.texts[3 * i - 2], p, text, x, y, S.TEXT)
    S.PenText(p.texts[3 * i - 1], p, text, x2, y - 1, 0x25)
    S.PenText(p.texts[3 * i], p, text, x3, y - 1, 0x25)
end

--- DrawNumberString 0x00569D80: text in 9X11FONT's digits of set v from (x, y), a cell of 9 a character, a space left
--- empty, a minus FONTSYMB.EPF's frame 4.
local function number(p, key, text, v, x, y)
    p.numbers[key] = S.Number(p, text, v, x, y, p.numbers[key])
    if p.minus[key] then p.minus[key]:Hide() end
    local at = text:find("-", 1, true)
    if at then p.minus[key] = S.Picture(p, p.minus[key], "FONTSYMB.EPF", 4, "FONTSYMB.PAL", x + 9 * (at - 1), y, "ARTWORK") end
end

--- "%10u" in three groups of three and the first digit (the u32s at y 180, 200 and 220).
local function tenDigits(p, key, value, v, y)
    local text = string.format("%10.0f", math.max(0, math.floor(value or 0)))
    for g, x in ipairs({ 140, 109, 78 }) do
        local from = 8 - 3 * (g - 1)
        number(p, key .. g, text:sub(from, from + 2), v, x, y)
    end
    number(p, key .. 0, text:sub(1, 1), v, 65, y)
end

local function showEquipment(p)
    local worn, colours = {}, {}
    for i = 1, H:GetNumEquipmentSlots() do
        local _, _, code, itemName, iconId = H:GetEquipment(i)
        if itemName ~= "" then worn[code], colours[code] = iconId, H:GetEquipmentColour(i) end
    end
    p.hover:Hide()
    for code, b in pairs(p.gear) do
        local g, iconId = GEAR[code], worn[code]
        local up = p.over == b and iconId ~= nil
        if iconId then
            -- centred in its slot; moved (-2, -2) under the pointer, over LOOKICON's frame
            Look.Item(b.icon, p, iconId, colours[code], g.x + 24 - (up and 2 or 0), g.y + 24 - (up and 2 or 0))
        else
            b.icon:Hide()
        end
        if up then S.Picture(p, p.hover, "LOOKICON.EPF", g.frame, "LOOKICON.PAL", g.fx, g.fy, "BORDER") end
    end
    local states = SelfLook.States()
    for _, def in ipairs(SWITCHES) do
        local b, v = p.switches[def.id], states[def.id]
        if def.file == "STATBUTS.EPF" and v == 0xFF then
            -- not known yet (0xFF before the server's 0x39): the rectangle filled 0x8F
            b.tex:ClearAllPoints()
            b.tex:SetAllPoints(b)
            S.Fill(b.tex, 0x8F)
            b.tex:Show()
        else
            -- the frame at its own size from the rectangle's corner (RenderTileFrame into the slot's bounds)
            b.tex = S.Picture(p, b.tex, def.file, v ~= 0 and def.on or def.off, "BUTTON.PAL", def.rect[1], def.rect[2])
        end
    end
    -- button 2: filled 0x8F while its state is 0xFF; 4a looks its frame up otherwise but draws nothing
    p.stats.tex:SetShown(H:GetSelfLookStatsToggle() == 0xFF)
    if p.stats.tex:IsShown() then
        p.stats.tex:SetAllPoints(p.stats)
        S.Fill(p.stats.tex, 0x8F)
    end
end

local function showStatus(p)
    local _, line1, line2 = H:GetSheet()
    triple(p, 1, line1 or "", 59, 25, 58, 57)
    triple(p, 2, line2 or "", 59, 45, 58, 57)
    local nation, spirit = H:GetPlayerOrigin()
    nation, spirit = sbyte(nation), sbyte(spirit)
    if nation ~= -1 then
        local text = NATIONS[nation + 1] or ""
        local hw = div(S.TextWidth(text) or 0, 2)
        triple(p, 3, text, 64 - hw, 86, 64 - hw, 63 - hw)
    end
    if spirit ~= -1 then
        local text = SPIRITS[spirit + 1] or ""
        local hw = div(S.TextWidth(text) or 0, 2)
        triple(p, 4, text, 133 - hw, 86, 133 - hw, 132 - hw)
    end
    local aux = H:GetSheetAuxiliary() or ""
    if #aux > 7 then triple(p, 5, aux:sub(8), 58, 105, 58, 57) end
    -- the three percentages, each centred in its 32 pixels (PercentStatA +15 might, B +19 grace, C +16 will)
    local might, will, grace = H:GetPlayerStats()
    for i, def in ipairs({ { might, 24 }, { grace, 83 }, { will, 142 } }) do
        local text = string.format("%d", math.max(0, def[1] or 0))
        number(p, "pct" .. i, text, 1, def[2] + div(32 - 9 * #text, 2), 120)
    end
    local ok, b0, b1, b2, value = H:GetSheetSummary()
    if not ok then b0, b1, b2, value = 0, 0, 0, 0 end
    for i, def in ipairs({ { b0, 110, 140 }, { b1, 83, 160 }, { b2, 168, 160 } }) do
        local text = string.format("%d", def[1])
        number(p, "sum" .. i, text, 2, def[2] - 9 * #text, def[3])
    end
    tenDigits(p, "value", value, 0, 180)
    local _, _, hpMax, _, mpMax = H:GetUnitVitals("player")
    tenDigits(p, "vita", hpMax, 2, 200)
    tenDigits(p, "mana", mpMax, 2, 220)
end

function P.Show(p)
    if not p:IsShown() then return end
    local view = p.view
    S.Picture(p, p.back, "SELFLOOK.EPF", view, "LOOKICON.PAL", 0, 0, "BACKGROUND")
    for _, fs in ipairs(p.texts) do fs:Hide() end
    for _, list in pairs(p.numbers) do for _, t in ipairs(list) do t:Hide() end end
    for _, t in pairs(p.minus) do t:Hide() end
    -- view 0's controls exist in view 0 only (GetSlotRect: -1 in the others): hidden, they take no press
    local equipment = view == 0
    for _, b in pairs(p.gear) do
        b:SetShown(equipment)
        if not equipment then b.icon:Hide() end
    end
    for _, b in pairs(p.switches) do
        b:SetShown(equipment)
        b.tex:SetShown(equipment and b.tex:IsShown())
    end
    p.stats:SetShown(equipment)
    if equipment then
        showEquipment(p)
    else
        p.hover:Hide()
        if view == 1 then showStatus(p) end
    end
    p.legend:SetShown(view == 2)
    if view == 2 and not p.legendShown then
        -- ShowLegendPane (0x00567380): the marks, scrolled to the end, each time the view is shown
        local lines = {}
        for i = 1, H:GetNumLegend() do
            local _, text, symbol, colour = H:GetLegend(i)
            K.Wrap(lines, text, 160, colour, symbol)
        end
        p.legend:Set(lines, true)
    end
    p.legendShown = view == 2 or nil
    local n, b = NEXT[view], BACK[view]
    p.next:Place(n and n[1], n and n[2])
    p.previous:Place(b and b[1], b and b[2])
end

return P
