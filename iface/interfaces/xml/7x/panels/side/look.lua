-- s6-interface-7x-b (round 5; the owner, 2026-10-05): 7.x's look at another player (side panel tab 1), 7.5.2's own pane,
-- 4a's UserLookPane (ui/UserLookPane.cpp), drawn in the side panel in place of Modern's look window (core/look.lua).
-- Each 0x34 shows it again on its first view (MapPane::SwitchPanelTab1WithClickAndStopTimer 0x005119B0: SwitchActiveTab(1)
-- and sample 0x198; OnActivate 0x0059F610 ends in ShowMoreInfoView 0x005A1CD0).
--
-- Four views (m_viewMode), stepped by the arrows and Page Up / Page Down, stopping at either end (HandlePointerOrMouseEvent
-- 0x005A1580 cases 2 and 3, HandleKeyOrTextEvent 0x005A19A0); drawn as OnPaint 0x005A0640:
--   0  USERLOOK.EPF 0 in USERLOOK.PAL: the header, the name and the three identity lines, each a 0x80 shadow a pixel
--      right and down, then the text (the header centred on 34, at 2 when it would start left of 3; the name centred on
--      117 in 0x8F when highlighted, else 0x0A; the lines centred on 105 at y 44, 65, 86, in 0x8F); the figure (a human's
--      composition with its bottom at 187 and its cell's left at 54, a creature centred on (78, 131): the drawing's
--      "look-pane" picture, USERLOOK.EPF 0 with the figure at its place); the two action buttons (STATBUT.EPF in
--      BUTTON.PAL at their own size from their corner; filled 0x8F while their state byte is 0xFF); the more-info text
--      (7, 205)-(182, 266), its tabs line breaks
--   1  USERLOOK.EPF 1: the fourteen items, each its whole frame centred on its place, dyed by its colour byte
--   2  PFLOOK.EPF 0 in PFLOOK.PAL: the portrait in (70, 48)-(118, 104) (the packet's, else FACE.EPF at half size) and the
--      profile text (17, 120)-(174, 240)
--   3  USERLOOK.EPF 3: the legend (7, 15)-(182, 265), scrolled to its end
-- The text panes are 4a's TextEditPanes (font 0 in 0x80, 12-pixel lines, wrapped at 145 pixels, the legend's at 160; a
-- bar along their right while they can scroll: K.TextPane).
--
-- WIRE (HandlePointerOrMouseEvent 0x005A1580, a single left press, event type 1; the releases and a double click's second
-- press do nothing): button 0 at (146, 112)-(182, 148) sends 4A 00 and the player's id (SendUserLookTargetActionPacket
-- 0x005A2280), button 1 at (146, 148)-(182, 184) sends 2E and the name (SendUserLookNameCommandPacket 0x005A2190); both
-- refused while the look's first state byte is 0xFF, the press still taken. They are Modern's look window's actions
-- (look:trade, look:group: TK.Game.Look.ActionButton runs them on the press), sent by TK-Core LookRules, so a press here
-- sends what a press on Modern's buttons sends, at the same moment. The buttons exist in view 0 only (GetActionButtonRect
-- 0x005A1A70: -1 in the others), so a press where they were sends nothing in the other views. Changing their place,
-- their views, their actions or the press that runs them changes what the server sees. A right press on them shows 4a's
-- help line (strings 200 and 201, 5 s); the arrows and the keys send nothing.
-- s6-ui-core (round 85): the XML twin's scripts; the page, its buttons', items' and arrows' places are look.xml's
-- (core/xml.md).

local H = __tk
local S = require("interfaces.7x.skin")
local K = require("interfaces.7x.panels.side.kit")
local Elements = require("interfaces.7x.panels.side.elements") -- the kit as layout elements (the twin's own)
local Hud = require("interfaces.7x.hud")

local L = {}

local X = TK.Xml.Data("look.xml")

-- View 1's items by the packet's record: the point each is centred on (look.xml's ITEMS)
local ITEMS = X.ITEMS

-- The arrows' places by view (look.xml's NEXT and BACK)
local NEXT, BACK = {}, {}
for _, at in ipairs(X.NEXT) do NEXT[at.view] = { at.x, at.y } end
for _, at in ipairs(X.BACK) do BACK[at.view] = { at.x, at.y } end

--- Whole equipment frames retain their colour byte and the active panel's 500 ms
--- palette repaint (4a ScreenPane 0x00556D50). Use the same native item placement
--- as inventory rows; dialog pictures still keep TK.Art.Item's requested phase.
function L.Item(tex, page, iconId, colour, cx, cy)
    S.Item(tex, page, iconId, cx, cy, 1, nil, colour)
end

local function step(p, delta)
    p.view = math.max(0, math.min(3, p.view + delta))
    L.Show(p)
end

-- the scripts look.xml names
local scripts = {}

-- WIRE: Modern's look window's action on the button's left press (the header)
function scripts.ActionButton(b) TK.Game.Look.ActionButton(b, b.action) end

-- its help on the right press. WIRE (s6-interface-7x-b round 6): UserLookPane::HandlePointerOrMouseEvent
-- (0x005A1580) shows it for type 4 only, so a right double press (type 5) shows none; the tip uses up the next
-- press (Hud.HelpLine.Show), so a tip 4a does not show would take a press 4a sends on (Trade's 4A 00)
function scripts.Help(b)
    b:HookScript("OnMouseDown", function(_, button, double)
        if button == "RightButton" and not double then Hud.HelpLine.Show(b:GetParent(), H:OriginalString(b.help) or "", 5000) end
    end)
end

function scripts.Next(p) step(p, 1) end

function scripts.Previous(p) step(p, -1) end

-- a new look's data may come a moment after its tab switch, and its figure once the drawing has painted it: the page
-- draws the look again when it changes, and view 0's picture a few times a second (as Modern's look window does)
function scripts.Watch(p)
    p:SetScript("OnUpdate", TK.Util.Throttled(0.2, function()
        if H:GetLook() ~= p.serial then L.Show(p) elseif p.view == 0 then L.Background(p) end
    end))
end

function L.Build(parent)
    return TK.Xml.Load("look.xml", { scripts = scripts, elements = Elements, parent = parent }).frame
end

-- the views' pictures (look.xml's FILES)
local FILES = {}
for _, v in ipairs(X.FILES) do FILES[v.view] = v end

--- The view's picture: view 0's with the figure painted in at its place (the drawing's "look-pane"), without one yet
--- USERLOOK.EPF 0 alone; the other views' their own.
function L.Background(p)
    local key, w, h = "", 0, 0
    if p.view == 0 then key, w, h = H:GetFigure("look-pane", 0) end
    if key ~= "" then
        if key == p.backKey then return end
        p.back:SetTexture(key)
        p.back:SetVertexColor(1, 1, 1, 1)
        p.back:SetSize(w, h)
        p.back:ClearAllPoints()
        p.back:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
        p.back:Show()
    else
        local f = FILES[p.view]
        S.Picture(p, p.back, f.file, f.frame, f.palette, 0, 0, "BACKGROUND")
    end
    p.backKey = key
end

--- OnActivate (each 0x34): the first view, the text panes filled again.
function L.Activate(p)
    p.view = 0
    p.serial = nil
end

--- Page Up and Page Down: the views back or on as the arrows, taken at either end too (HandleKeyOrTextEvent returns true).
function L.Page(p, delta)
    step(p, delta)
    return true
end

--- A text at the pen (x, y) with its 0x80 shadow at (sx, sy) (OnPaint's pairs).
local function pair(p, i, text, sx, sy, x, y, colour)
    S.PenText(p.texts[2 * i - 1], p, text, sx, sy, S.TEXT)
    S.PenText(p.texts[2 * i], p, text, x, y, colour)
end

function L.Show(p)
    if not p:IsShown() then return end
    local serial, name, header, line1, line2, line3 = H:GetLook()
    local _, moreInfo, profile, groupState, tradeState, highlighted, portrait = H:GetLookDetail()
    if serial ~= p.serial then
        -- the texts of a new look (OnActivate): the more info and the profile from their tops, the legend at its end
        p.serial = serial
        local lines = {}
        K.Wrap(lines, ((moreInfo or ""):gsub("\t", "\n")), 145)
        p.moreInfo:Set(lines)
        p.profile:Set(K.Wrap({}, profile, 145))
        local legend = {}
        for i = 1, H:GetNumLookLegend() do
            local _, text, symbol, colour = H:GetLookLegend(i)
            K.Wrap(legend, text, 160, colour, symbol)
        end
        p.legend:Set(legend, true)
    end
    local view = p.view
    for _, fs in ipairs(p.texts) do fs:Hide() end
    for _, t in ipairs(p.items) do t:Hide() end
    p.face:Hide()
    p.backKey = nil
    L.Background(p)
    if view == 0 then
        local hw = math.floor((S.TextWidth(header) or 0) / 2)
        local hx = 35 - hw
        pair(p, 1, header, hx > 3 and hx or 3, 25, hx > 3 and 34 - hw or 2, 24, 0x8F)
        local nw = math.floor((S.TextWidth(name) or 0) / 2)
        pair(p, 2, name, 118 - nw, 25, 117 - nw, 24, highlighted and 0x8F or 0x0A)
        for i, text in ipairs({ line1, line2, line3 }) do
            local lw = math.floor((S.TextWidth(text) or 0) / 2)
            pair(p, 2 + i, text, 106 - lw, 24 + 21 * i, 105 - lw, 23 + 21 * i, 0x8F)
        end
    elseif view == 1 then
        for i, at in ipairs(ITEMS) do
            local _, _, iconId = H:GetLookItem(i)
            if iconId and iconId >= 0 then L.Item(p.items[i], p, iconId, H:GetLookItemColour(i), at.x, at.y) end
        end
    elseif view == 2 then
        -- the portrait in (70, 48)-(118, 104), 48 x 56, as it came; else FACE.EPF's frame at half size, with no palette of
        -- its own (OnPaint: palette 0, the port's current one; BARAM.PAL, as the skin's digits and symbols take it)
        if portrait ~= "" then
            p.face:SetTexture(portrait)
            p.face:SetVertexColor(1, 1, 1, 1)
            K.Place(p.face, p, 70, 48, 118, 104)
            p.face:Show()
        else
            local fk, fw, fh = TK.Art.Image("FACE.EPF", H:GetLookFaceFrame(), "BARAM.PAL")
            if fk then
                p.face:SetTexture(fk)
                p.face:SetVertexColor(1, 1, 1, 1)
                local ox, oy = TK.Art.Origin(fk)
                p.face:SetSize(math.max(1, math.floor(fw / 2)), math.max(1, math.floor(fh / 2)))
                p.face:ClearAllPoints()
                p.face:SetPoint("TOPLEFT", p, "TOPLEFT", 70 + math.floor(ox / 2), -(48 + math.floor(oy / 2)))
                p.face:Show()
            end
        end
    end
    -- the buttons in view 0 only: button 0's picture by the second state byte (7 on, 2 off), button 1's by the first (8, 3)
    for i, b in ipairs(p.buttons) do
        b:SetShown(view == 0)
        b.tex:Hide()
        if view == 0 then
            local state = i == 1 and tradeState or groupState
            if state == 0xFF then
                b.tex:ClearAllPoints()
                b.tex:SetAllPoints(b)
                S.Fill(b.tex, 0x8F)
                b.tex:Show()
            else
                local frame = i == 1 and (state ~= 0 and 7 or 2) or (state ~= 0 and 8 or 3)
                b.tex = S.Picture(b, b.tex, "STATBUT.EPF", frame, "BUTTON.PAL", 0, 0, "ARTWORK")
            end
        end
    end
    p.moreInfo:SetShown(view == 0)
    p.profile:SetShown(view == 2)
    p.legend:SetShown(view == 3)
    local n, b = NEXT[view], BACK[view]
    p.next:Place(n and n[1], n and n[2])
    p.previous:Place(b and b[1], b and b[2])
end

return L
