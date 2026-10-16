-- s6-optimize (round 52; R51.6, moved from panels/playerframe/main.lua and panels/targetframe/main.lua, which built it the
-- same): Modern's unit portrait, the player frame's and the target frame's. A round frame of size pixels: a disc in the
-- unit's colour, the character's picture over it (portrait.picture, hidden until s6-characters' portrait or a profile
-- picture is shown), the name's letter while there is neither (portrait.glyph), and the gold ring over them all. The
-- frame shows and fills it.
-- s6-ui-core (round 85): the XML twin's; the portrait's parts are portrait.xml's template (core/xml.md), made here for
-- the panel that asks.

local E = require("interfaces.modern.elements")

local ui = TK.Xml.Load("portrait.xml", { elements = E })

local P = {}

--- A portrait on parent, size x size, at point (its own and parent's) + (x, y), its disc in r, g, b.
function P.New(parent, size, point, x, y, r, g, b)
    local portrait = ui:New("Portrait", parent)
    portrait:SetSize(size, size)
    portrait:SetPoint(point, parent, point, x, y)
    portrait.disc:SetVertexColor(r, g, b, 1)
    return portrait
end

return P
