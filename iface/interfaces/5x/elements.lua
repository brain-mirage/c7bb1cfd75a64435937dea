-- s6-ui-core (round 85): the elements 5.x's XML twin gives its layout files beside the loader's own (core/xml.md,
-- "An interface's own elements"): each makes what the original's Lua makes with 5.x's skin and its scroll bar, with the
-- same calls in the same order, so a layout file can say it where the original's code said it. Drawing only, but for
-- the presses <press> and <scrollbar> take (their notes).
--   <picture file frame palette x y layer/>     a 5.33 picture at (x, y) of its frame (S.Picture; no palette: BARAM.PAL)
--   <fill index alpha layer/>                   a texture filled with a palette colour (S.Fill)
--   <skintext colour layer/>                    a font string in 5.33's font 0 and a colour (S.Text; S.TEXT by default)
--   <scrollbar skin right t b range set/>       5.33's scroll bar at the right of (right - its width) a pane's rows t-b
--                                               (Bar.New): range(frame) gives the pane's range, position and page,
--                                               set(frame, pos) scrolls it there
--   <press l t r b call/>                       an invisible button over (l, t)-(r, b), call(frame) on its left press (the
--                                               panes' type 1 buttons: the pages and views; local, nothing sent)
-- A colour is a palette index or the skin's name for one (TEXT, WHITE...).

local S = require("interfaces.5x.skin")
local Bar = require("interfaces.5x.scrollbar")

local E = {}

--- A colour attribute: an index, or the skin's field of that name.
local function colour(v)
    if type(v) == "string" then return S[v] end
    return v
end

function E.picture(parent, a)
    return S.Picture(parent, nil, a.file, a.frame, a.palette, a.x, a.y, a.layer)
end

function E.fill(parent, a)
    return S.Fill(parent:CreateTexture(nil, a.layer or "ARTWORK"), colour(a.index), a.alpha)
end

function E.skintext(parent, a)
    return S.Text(parent:CreateFontString(nil, a.layer or "ARTWORK"), colour(a.colour))
end

function E.scrollbar(parent, a, ctx)
    local range, set = ctx.scripts[a.range], ctx.scripts[a.set]
    return Bar.New(parent, a.right - Bar.Width(a.skin), a.t, a.b, a.skin, {
        Range = function() return range(parent) end,
        Set = function(pos) set(parent, pos) end,
    })
end

function E.press(parent, a, ctx)
    local fn = ctx.scripts[a.call]
    local btn = CreateFrame("Button", nil, parent)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", a.l, -a.t)
    btn:SetSize(a.r - a.l, a.b - a.t)
    btn:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then fn(parent) end end)
    return btn
end

return E
