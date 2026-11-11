-- s6-devtools (round 5; the interface separation's step 5: docs/development/interface-separation.md 4.4 and 5.15, open
-- question 49, decision 2026-10-05-original-kit-and-tool-skin): the original client's palette indexes and digits, for
-- any interface that draws as the original does (7.x's and 5.x's skins take them: setmetatable(skin, { __index = this
-- })). Moved from 7.x's skin (interfaces/7x/skin.lua, s6-modular-g's phase 3), which 5.x's inherited: 7.5.2 and 5.33 use
-- the same BARAM.PAL indexes and the same 9X11FONT.BIN, byte for byte. Colours are BARAM.PAL's indexes, as the
-- original's GrafPort takes them (its default text colour 0x80); numbers are 9X11FONT.BIN's digits
-- (NumericStringControlPane and its kin), 9 pixels apart. Drawing only: nothing here is sent.

local H = __tk

local P = {}

-- The palette's colours, read once each (the packs never change while the client runs).
local cache = {}

--- Colour index of BARAM.PAL (or of another palette of the packs: s6-interface-7x round 2, the power dialog's SUPER
--- swatches) as r, g, b (0 to 1); without the packs, black for the text colour and grey for others.
function P.Colour(index, palette)
    palette = palette or "BARAM.PAL"
    local id = palette == "BARAM.PAL" and index or palette .. index
    local c = cache[id]
    if not c then
        local ok, r, g, b = H:GetPaletteColour(palette, index)
        c = ok and { r, g, b } or (index == 0x80 and { 0, 0, 0 } or { 0.5, 0.5, 0.5 })
        cache[id] = c
    end
    return c[1], c[2], c[3]
end

-- The indexes the original's panes use (Source-5: GrafPort's defaults, the dialogs' controls, the lists).
P.TEXT = 0x80          -- every text (GrafPort's default text colour)
P.DISABLED = 0x86      -- a disabled text button's caption, the Enter frame of a disabled default button
P.ENTER = 0x84         -- the Enter frame round a dialog's default button (DialogPane::OnPaint)
P.LIST = 0x25          -- a list row's text, and the selected row's bar (TextMenuItemList, MenuQuestionItemList)
P.WHITE = 0x8F         -- the help line's and an outlined text's lines, a disabled bar's wash, a raised edge's light

--- A texture filled with a colour index (alpha a, 1 by default; of BARAM.PAL unless a palette is named).
function P.Fill(tex, index, a, palette)
    local r, g, b = P.Colour(index, palette)
    tex:SetColorTexture(r, g, b, a or 1)
    return tex
end

--- Digit d (0-9) of 9X11FONT.BIN's colour variant v: the art key and its size, and where the picture starts in its
--- 9 x 11 cell; nil without the packs. The file's glyph 10 v + d (the original puts a blank glyph in front of the file:
--- GrafPort::InitNumericGlyphTileContext, character c of variant v at ((c - '/') + 10 v)).
function P.Digit(d, v)
    local key, w, h = TK.Art.Digit(10 * (v or 0) + d, "BARAM.PAL")
    if not key then return nil end
    local x, y = TK.Art.Origin(key)
    return key, w, h, x, y
end

--- A number drawn in 9X11FONT.BIN's digits on parent, its first cell's top left at (x, y) from parent's top left: one
--- 9-pixel cell a character, spaces and '/' left empty as the original skips them (NumericStringControlPane::OnPaint).
--- Returns the textures (reused when given back as into).
function P.Number(parent, text, v, x, y, into)
    local out = into or {}
    for _, t in ipairs(out) do t:Hide() end
    local n = 0
    for i = 1, #text do
        local d = tonumber(text:sub(i, i))
        if d then
            local key, w, h, ox, oy = P.Digit(d, v)
            if key then
                n = n + 1
                local t = out[n] or parent:CreateTexture(nil, "ARTWORK")
                out[n] = t
                t:SetTexture(key)
                t:SetSize(w, h)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (i - 1) * 9 + ox, -(y + oy))
                t:Show()
            end
        end
    end
    return out
end

return P
