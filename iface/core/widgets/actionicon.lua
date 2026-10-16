-- Shared action icon paint and the held-icon frame, moved from core/cursor.lua before the skin split.
-- The caller supplies its skin; action lookup defaults to TK.ActionIconInfo in core/cursor.lua.
-- An optional info callback replaces that lookup. This widget changes pictures only, never the held action.
-- The tools own the held cursor look in every interface (the separation plan, step 5).
local A = { CURSOR_SIZE = 32 }

--- Builds a named held icon following the root pointer, using S for its glyph. Drawing only.
function A.Cursor(S, name)
    local W = TK.UI.With(S)
    local icon = CreateFrame("Frame", name, UIParent)
    icon:SetFrameStrata("TOOLTIP")
    icon:SetSize(A.CURSOR_SIZE, A.CURSOR_SIZE)
    icon:Hide()
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.glyph = W.Label(icon, "", 18, S.white)
    icon.glyph:SetFont(18, "OUTLINE")
    icon.glyph:SetPoint("CENTER", icon, "CENTER", 0, 0)
    icon:SetAlpha(0.85)
    icon:SetScript("OnUpdate", function(self)
        local x, y = TK.Util.CursorRoot()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + 12, y - 12)
    end)
    return icon
end

--- Shows an action's icon in a texture (and its letter in a font string): the original's picture when there is
--- one, centred on anchor, else the placeholder square with the letter, filling anchor less inset. box is the space
--- the icon has, in pixels. Returns whether it shows anything, whether that is a picture, and for a spell whether the
--- book lacks it (the animators darken it). S gives the placeholder tint. info(action), when supplied,
--- replaces TK.ActionIconInfo and returns name, key, letter, count, art, width, height, missing.
function A.Draw(S, tex, glyph, anchor, action, box, inset, info)
    local name, key, letter, _, art, w, h, missing = (info or TK.ActionIconInfo)(action)
    if not name then
        tex:SetTexture("")
        glyph:SetText("")
        return false
    end
    if art then
        TK.Art.Place(tex, anchor, art, w, h, box)
        glyph:SetText("")
    else
        inset = inset or 0
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", anchor, "TOPLEFT", inset, -inset)
        tex:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -inset, inset)
        tex:SetTexture("icon:" .. key)
        local tint = S.white
        tex:SetVertexColor(tint[1], tint[2], tint[3], tint[4] or 1)
        glyph:SetText(letter)
    end
    return true, art ~= nil, missing
end

return A
