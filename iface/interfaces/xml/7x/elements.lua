-- s6-ui-core (round 85): the elements 7.x's XML twin gives its layout files beside the loader's own (core/xml.md,
-- "An interface's own elements"): each makes what the original's Lua makes with 7.x's skin and drawing kit, with the same
-- calls in the same order, so a layout file can say it where the original's code said it. Drawing only.
--   <picture file frame palette x y layer/>        an interface picture at (x, y) of its frame (S.Picture)
--   <bold x baseline colour layer of/>             a bold text, its pen at (x, baseline) of the frame of (its own frame by
--                                                  default; X.Bold)
--   <tiles width height file palette size/>        a window's tiled background and border on its frame (X.Frame)
--   <outline l right h tracked manual/>            a row's raised outline; it is the row's paint function (X.Outline)
-- A colour is a palette index or the skin's name for one (TEXT, SHADOW...).

local S = require("interfaces.7x.skin")
local X = require("interfaces.7x.draw")

local E = {}

--- A colour attribute: an index, or the skin's field of that name.
local function colour(v)
    if type(v) == "string" then return S[v] end
    return v
end

function E.picture(parent, a)
    return S.Picture(parent, nil, a.file, a.frame, a.palette, a.x, a.y, a.layer)
end

function E.bold(parent, a)
    local fs = parent:CreateFontString(nil, a.layer or "OVERLAY")
    X.Bold(a.of or parent, fs, a.x, a.baseline, colour(a.colour))
    return fs
end

function E.tiles(parent, a)
    X.Frame(parent, a.width, a.height, a.file, a.palette, a.size)
end

function E.outline(parent, a)
    return X.Outline(parent, a.l, a.right, a.h, a.tracked, a.manual)
end

return E
