-- A character's drawing helpers (docs/development/interface-separation.md, sections 4.1 and 5.15; s6-modular-g round 16,
-- separation step 7): a gear slot, the figure box and its figure, the stat lines and the legend list, drawn the same way
-- by Modern's character and look windows (interfaces/modern/panels/windows/) and the Library's pages (core/library/). They
-- were the character window's (TK.CharacterWindow.GearSlot and the rest, s6-library-pages); they are global widgets
-- because the Library, a tool, draws with them in every interface. Drawing only: nothing here is sent, and a slot's
-- actions are its caller's (Modern's gear slots take the game layer's worn-item control, TK.Game.SelfLook.WornControl).

local H = __tk
local W = TK.UI

local CH = {}
W.Character = CH

-- The figure's background (0xRRGGBB): the box it is painted onto (the look is asked for on this colour, so a translucent
-- look blends as the original's does).
CH.FIGURE_BG = { 0x1C, 0x1C, 0x21 }

--- A gear slot as the Character tab draws it, without its actions (the Library's Overview draws a character's gear
--- with it too): the slot's box, the item's icon, and its slot's and item's names beside it, on the side the slot sits.
--- Fill it with CH.FillGearSlot.
function CH.GearSlot(page, name, x, y, point)
    local s = CreateFrame("Button", name, page)
    s:SetSize(38, 38)
    s:SetPoint(point, page, point, x, y)
    s.icon = select(2, W.SlotArt(s)) -- s6-ui-core (round 62): the shared slot's picture, an item's edge, the light
    local left = point == "TOPLEFT"
    s.label = W.Label(page, "", 11, { 0.75, 0.75, 0.75 }, left and "LEFT" or "RIGHT")
    s.item = W.Label(page, "", 11, W.white, left and "LEFT" or "RIGHT")
    if left then
        s.label:SetPoint("TOPLEFT", s, "TOPRIGHT", 6, -3)
        s.item:SetPoint("TOPLEFT", s.label, "BOTTOMLEFT", 0, -3)
    else
        s.label:SetPoint("TOPRIGHT", s, "TOPLEFT", -6, -3)
        s.item:SetPoint("TOPRIGHT", s.label, "BOTTOMRIGHT", 0, -3)
    end
    return s
end

--- A gear slot's slot name, item name and icon (the ITEM.EPF frame; none for an empty slot).
function CH.FillGearSlot(s, slotName, itemName, iconId)
    s.label:SetText(slotName)
    s.item:SetText(itemName)
    local art, w, h = TK.Art.Icon(iconId)
    if itemName ~= "" and art then
        TK.Art.Place(s.icon, s, art, w, h, 38)
        s.icon:Show()
    else
        s.icon:Hide()
    end
end

--- The Character tab's figure box (the Library's Overview has one too): 120 x 190 in the figure's background colour,
--- with its figure texture (box.figure) standing on its bottom.
function CH.FigureBox(page, name)
    local bg = CH.FIGURE_BG
    local box = CreateFrame("Frame", name, page)
    box:SetSize(120, 190)
    box:SetBackdrop({ bg = { bg[1] / 255, bg[2] / 255, bg[3] / 255, 1 }, edge = false, bgFile = "tk:white" })
    box.figure = box:CreateTexture(nil, "ARTWORK")
    box.figure:SetPoint("BOTTOM", box, "BOTTOM", 0, 8)
    return box
end

--- A figure picture (key, width, height) in its box, scaled by whole steps to fit it; the emoji for none ("").
function CH.PlaceFigure(figure, key, w, h)
    if key == "" then
        figure:SetTexture("emoji:1f9cd")
        figure:SetSize(80, 80)
        return
    end
    local scale = math.max(1, math.min(3, math.floor(math.min(170 / h, 110 / w))))
    figure:SetTexture(key)
    figure:SetSize(w * scale, h * scale)
end

--- The Character tab's two stat columns as text (the Library's Overview shows a character's the same way): vita, mana,
--- experience and gold; Might, Will and Grace.
function CH.StatsText(hp, hpMax, mp, mpMax, experience, gold)
    local F = TK.Util.FormatNumber
    return string.format("Vita  %s / %s\nMana  %s / %s\nExperience  %s\nGold  %s", F(hp or 0), F(hpMax or 0), F(mp or 0),
        F(mpMax or 0), F(experience or 0), F(gold or 0))
end

function CH.StatsText2(might, will, grace)
    return string.format("Might  %d\nWill  %d\nGrace  %d", might or 0, will or 0, grace or 0)
end

--- A colour of the base palette (BARAM.PAL), or black without the packs (the legend's backdrop is light).
local function paletteColour(index)
    local ok, r, g, b = H:GetPaletteColour("BARAM.PAL", index)
    if ok then return { r, g, b } end
    return { 0, 0, 0 }
end

-- The legend's backdrop: the original's colours are chosen for its light legend page (SELFLOOK.EPF frame 2, USERLOOK.EPF
-- frame 3) and are unreadable on our dark panels (the live check's dark red on black), so the list sits on parchment.
local LEGEND_BG = { 0.87, 0.82, 0.70 }

--- A legend (the original's LegendPane: Modern's character and look windows, the Library's Legend page): each line's
--- mark, frame `symbol` of SYMBOLS.EPF, and its text in its colour, both through the base palette (PaletteLib's
--- baram.pal: the original passes none for either), scrolled to the end as the original shows it.
--- list:Fill(n, get, empty): get(i) returns text, symbol, colour.
function CH.LegendList(parent, width, height)
    local sf, content = W.ScrollArea(parent)
    sf:SetSize(width, height)
    content:SetWidth(width)
    sf.wheelStep = 18
    local bg = sf:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(sf)
    bg:SetColorTexture(LEGEND_BG[1], LEGEND_BG[2], LEGEND_BG[3], 1)
    local list = { sf = sf, rows = {} }
    list.empty = W.Label(content, "", 12, { 0.3, 0.3, 0.3 }, "LEFT")
    list.empty:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
    function list:Fill(n, get, empty)
        for i = 1, math.max(n, #self.rows) do
            local row = self.rows[i]
            if not row and i <= n then
                row = CreateFrame("Frame", nil, content)
                row:SetSize(width - 8, 18)
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4 - (i - 1) * 18)
                row.mark = row:CreateTexture(nil, "ARTWORK")
                row.mark:SetSize(12, 12)
                row.mark:SetPoint("LEFT", row, "LEFT", 2, 0)
                row.text = W.Label(row, "", 12, W.white, "LEFT")
                row.text:SetPoint("LEFT", row, "LEFT", 20, 0)
                row.text:SetWidth(width - 32)
                self.rows[i] = row
            end
            if row then
                if i <= n then
                    local text, symbol, colour = get(i)
                    local key = TK.Art.Image("SYMBOLS.EPF", symbol, "BARAM.PAL")
                    row.mark:SetTexture(key or "tk:circle")
                    row.mark:SetShown(true)
                    row.text:SetText(text)
                    W.Color(row.text, paletteColour(colour))
                end
                row:SetShown(i <= n)
            end
        end
        self.empty:SetText(n == 0 and (empty or "") or "")
        content:SetHeight(math.max(10, n * 18 + 8))
        sf:SetVerticalScroll(sf:GetVerticalScrollRange())
        sf.Refresh()
    end
    return list
end

return CH
