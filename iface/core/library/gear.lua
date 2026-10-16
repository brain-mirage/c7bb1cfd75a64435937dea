-- A character drawn as the game's Character tab draws one (s6-library-pages): its 14 gear slots in two columns, its name
-- and a line under it, and its figure in its look as last seen, gear and all. The Characters page's Overview and the
-- Players page both use it. The slots, the figure box and the figure's placing are the Character tab's, the global
-- widgets' (TK.UI.Character.GearSlot, FillGearSlot, FigureBox, PlaceFigure: core/widgets/character.lua); the look is
-- drawn as the dialogs draw a human (library/pictures.lua). Drawing only: nothing is sent.

local W = TK.UI
local H = __tk
local L = TK.Library

local DIM = { 0.62, 0.62, 0.66 }

--- The gear panel in parent (440 x 400 from its top left): g.slots, g.name, g.info, g.figureBox, g.lines, g.seen.
function TK.LibraryGear(parent)
    local CH = TK.UI.Character -- s6-modular-g (round 16, separation step 7): the character window's helpers, now global
    local g = CreateFrame("Frame", nil, parent)
    g:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    g:SetSize(440, 400)
    g.slots = {}
    local n = H:GetNumEquipmentSlots()
    local half = math.ceil(n / 2)
    for i = 1, n do
        local left = i <= half
        local row = left and i - 1 or i - half - 1
        g.slots[i] = CH.GearSlot(g, nil, left and 4 or -4, -8 - row * 46, left and "TOPLEFT" or "TOPRIGHT")
        -- s6-library round 24: its item's tooltip, and a click opens the item's page, on the slot and on the item's name
        -- beside it (Astra's review: the name is in the link colour, so it takes the click too).
        L.LinkScripts(g.slots[i])
        g.slots[i].nameLink = L.LinkArea(g)
    end
    g.name = W.Label(g, "", 16, W.white)
    g.name:SetPoint("TOP", g, "TOP", 0, -10)
    g.name:SetWidth(150)
    g.info = W.Label(g, "", 12, W.gold)
    g.info:SetPoint("TOP", g.name, "BOTTOM", 0, -4)
    g.info:SetWidth(150)
    g.info:SetWordWrap(true)
    g.figureBox = CH.FigureBox(g, nil)
    g.figureBox:SetPoint("TOP", g, "TOP", 0, -74)
    g.lines = W.Label(g, "", 11, { 0.8, 0.8, 0.8 })
    g.lines:SetPoint("TOP", g.figureBox, "BOTTOM", 0, -6)
    g.lines:SetWidth(150)
    g.lines:SetWordWrap(true)
    g.seen = W.Label(g, "", 11, DIM, "LEFT")
    g.seen:SetPoint("TOPLEFT", g, "TOPLEFT", 4, -336)
    g.seen:SetWidth(430)
    g.seen:SetWordWrap(true)

    --- Shows a character: its name, the line under it, the lines under the figure, the 14 records ({ slot, name, icon }:
    --- the server's icon number, -1 for none; item, the Items page's key, where it lists the item), its look (43 status
    --- bytes, hex; "" for none: the Character tab's emoji) and the note under the slots.
    function g:Fill(name, info, lines, equipment, look, seen)
        L:Say(self.name, name)
        L:Say(self.info, info)
        L:Say(self.lines, lines)
        for i, slot in ipairs(self.slots) do
            local it = equipment and equipment[i] or {}
            -- The Library keeps the server's icon number (0xC000 and up); the Character tab draws ITEM.EPF's frame (+0x4000).
            local icon = (it.icon or -1) >= 0 and (it.icon + 0x4000) % 0x10000 or -1
            CH.FillGearSlot(slot, it.slot or "", it.name or "", icon)
            local worn = (it.name or "") ~= ""
            if worn then L.texts[#L.texts + 1] = it.slot .. ": " .. it.name end
            -- s6-library round 24 (the owner): the worn item's stats on hover; a click opens its page where it has one.
            -- (slot.item is the slot's name label, CH.GearSlot's.)
            slot.go, slot.tip = L.LinkTo("items", it.item), worn and L.ItemTip(it.name, it.slot, it.item) or nil
            W.Color(slot.item, it.item and L.LINK or W.white)
            L.LinkOver(slot.nameLink, slot.item, slot.go, nil, slot.tip)
        end
        -- The figure wears what the look shows: the look is the character's own 0x33 as last seen, its gear included.
        local key, w, h = TK.LibraryPictures.Picture("look", look, nil, 55, 85)
        CH.PlaceFigure(self.figureBox.figure, key or "", w, h)
        L:Say(self.seen, seen)
    end

    return g
end
