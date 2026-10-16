-- s6-modular-g (interfaces, phase 3's rest; docs/development/interfaces.md, section 3 "7.x", the skin): what
-- 7.x's panels and its dialogs look draw text and numbers with. Every text is BARAM00.EFT ("classic", the original's
-- font 0, 12-pixel lines; its glyphs beyond Latin-1 are built on first need: PackArt.EnsureClassicGlyphs); colours are
-- BARAM.PAL's indexes, as the original's GrafPort takes them (its default text colour 0x80); numbers are 9X11FONT.BIN's
-- digits (NumericStringControlPane and its kin), 9 pixels apart. Drawing only: nothing here is sent.
--
-- s6-interface-7x-b (round 8, the interface separation's step 5: docs/development/interface-separation.md, the row for
-- this file): the colours, the palette's indexes, Fill, Digit and Number are the original client's palette
-- (interfaces/original/palette.lua, moved there from here by s6-devtools), which this skin inherits; the font, the
-- pictures, the bars and the item pictures stay 7.x's.

local H = __tk

local S = setmetatable({}, { __index = require("interfaces.original.palette") })

-- 7.5.2's game screen: it runs at 1024 x 768 only (the EPF layout: Source-5's systems/entering-the-game-world.md).
S.WIDTH, S.HEIGHT = 1024, 768

-- 7.5.2's font 0's face, for the texts and the edits (the original-client kit's X.Edit takes it).
S.FACE = "classic"

--- A font string in the original's font and a colour index (S.TEXT by default), its lines 12 pixels apart as font 0's
--- (TextEditPane's line height; our classic font asset leaves 2 more, its cell + 2, for Modern's chat). In smaller
--- windows the whole original layout shrinks: text must follow its artwork to fit those fixed rectangles.
function S.Text(fs, index)
    fs:SetFont(S.FACE, 12, "SCALEWITHFRAME")
    fs:SetTextColor(S.Colour(index or S.TEXT))
    fs:SetSpacing(-2)
    return fs
end

--- A text's width in font 0 as the original measures it (GrafPort::GetTextWidth: the glyphs' advances), or nil without
--- the packs.
function S.TextWidth(text)
    local ok, w = pcall(function() return H:ClassicTextWidth(text or "") end)
    if ok and w and w >= 0 then return w end
    return nil
end

--- s6-modular-g (phase 5): frame n of an interface picture at (x, y) of parent (where the original puts the frame's top
--- left; the texture's crop added), in tex or a new texture on layer; hidden without the packs. Returns the texture.
function S.Picture(parent, tex, file, frame, palette, x, y, layer)
    tex = tex or parent:CreateTexture(nil, layer or "ARTWORK")
    local key, w, h = TK.Art.Image(file, frame, palette)
    if not key then
        tex:Hide()
        return tex
    end
    local ox, oy = TK.Art.Origin(key)
    tex:SetTexture(key)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:SetSize(w, h)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", x + ox, -(y + oy))
    tex:Show()
    return tex
end

--- A text where the original's pen draws it: the pen at (x, y), the bottom of font 0's 12-pixel line, so the line's top
--- 12 above it, the glyphs one pixel lower (as S.Text's lines sit). Returns the pen's x after it (the text advances it).
function S.PenText(fs, parent, text, x, y, index)
    S.Text(fs, index)
    fs:SetWordWrap(false)
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(y - 12 + 1))
    fs:Show()
    return x + (S.TextWidth(text) or fs:GetStringWidth())
end

--- Font-0 FitTextAndAppendSuffix (4a 0x004BA820): only a cut name gains
--- the supplied suffix, otherwise "...". Reuse the shared whole-character fit.
function S.Cut(text, width, suffix)
    return TK.Util.FitText(text or "", width, S.TextWidth, suffix)
end

--- Item picture iconId (ITEM.EPF's frame) in tex, its whole frame centred on (cx, cy) of parent at scale (1, or 0.5 for a
--- list's half-size picture), as the original centres it (GetItemGlyphBounds' frame, not the drawn pixels); hidden
--- without it. Returns the frame's drawn width and height.
S.Item = require("interfaces.original.itempicture")

--- A bar of BAR.EPF in BAR.PAL as the original fills it (UserStatusPane2::OnPaint, NewGroupPane's): w pixels ending at
--- right, the middle frame's last w pixels (frames { middle, left cap, right cap }), its 3-pixel caps outside both ends,
--- its top at y of parent; nothing for w 0 or less. parts keeps the textures between draws.
function S.Bar(parent, parts, frames, right, y, w)
    for _, t in pairs(parts) do t:Hide() end
    if w <= 0 then return end
    local key, fw, fh = TK.Art.Image("BAR.EPF", frames[1], "BAR.PAL")
    if not key then return end
    local _, oy = TK.Art.Origin(key)
    local mid = parts.mid or parent:CreateTexture(nil, "ARTWORK")
    parts.mid = mid
    local take = math.min(w, fw)
    mid:SetTexture(key)
    mid:SetVertexColor(1, 1, 1, 1)
    mid:SetTexCoord((fw - take) / fw, 1, 0, 1)
    mid:SetSize(take, fh)
    mid:ClearAllPoints()
    mid:SetPoint("TOPLEFT", parent, "TOPLEFT", right - take, -(y + oy))
    mid:Show()
    parts.left = S.Picture(parent, parts.left, "BAR.EPF", frames[2], "BAR.PAL", right - w - 3, y, "ARTWORK")
    parts.right = S.Picture(parent, parts.right, "BAR.EPF", frames[3], "BAR.PAL", right, y, "ARTWORK")
end

return S
