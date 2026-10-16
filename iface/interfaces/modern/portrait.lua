-- s6-optimize (round 52; R51.6, moved from panels/playerframe/main.lua and panels/targetframe/main.lua, which built it the
-- same): Modern's unit portrait, the player frame's and the target frame's. A round frame of size pixels: a disc in the
-- unit's colour, the character's picture over it (portrait.picture, hidden until s6-characters' portrait or a profile
-- picture is shown), the name's letter while there is neither (portrait.glyph), and the gold ring over them all. The
-- frame shows and fills it.

local W = require("interfaces.modern.skin").UI

local P = {}

--- A portrait on parent, size x size, at point (its own and parent's) + (x, y), its disc in r, g, b.
function P.New(parent, size, point, x, y, r, g, b)
    local portrait = CreateFrame("Frame", nil, parent)
    portrait:SetSize(size, size)
    portrait:SetPoint(point, parent, point, x, y)
    local disc = portrait:CreateTexture(nil, "ARTWORK")
    disc:SetAllPoints(portrait)
    disc:SetTexture("tk:circle")
    disc:SetVertexColor(r, g, b, 1)
    local ring = portrait:CreateTexture(nil, "OVERLAY")
    ring:SetAllPoints(portrait)
    ring:SetTexture("tk:ring")
    ring:SetVertexColor(0.85, 0.75, 0.45, 1)
    portrait.picture = portrait:CreateTexture(nil, "ARTWORK", nil, 1)
    portrait.picture:SetAllPoints(portrait)
    portrait.picture:Hide()
    portrait.glyph = W.Label(portrait, "", 26, W.white)
    portrait.glyph:SetFont(26, "OUTLINE")
    portrait.glyph:SetPoint("CENTER", portrait, "CENTER", 0, 1)
    return portrait
end

return P
