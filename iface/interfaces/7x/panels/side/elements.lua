-- s6-ui-core (round 85; round 86, round 85's final review, P3): 7.x's side panel's kit as layout elements, for its XML
-- layout files (core/xml.md, "An interface's own elements"). The kit itself is the original's
-- (interfaces/7x/panels/side/kit.lua, round 115: kept in place when the hand-written 7.x was archived), so its
-- drawing, its scroll bars' timing and capture are one code. Each element places a kit control with the
-- arguments its function takes; call="..." names the script (the loading Lua's) a press or a move runs, given the page
-- (and the scroll bar's position). The shared 7.x elements (interfaces/7x/elements.lua) come with them.
--   <invenbutton l t r b picture call/>   K.InvenButton, call(page) on its press
--   <scrollbar l t b call/>               K.ScrollBar, call(page, pos) on a move
--   <arrow picture call/>                 K.Arrow, call(page) on its press
--   <textpane l t r b/>                   K.TextPane
-- Drawing only: what a press sends is the script's, as in the original.

local K = require("interfaces.7x.panels.side.kit")

local function press(ctx, a, page)
    local fn = a.call and ctx.scripts[a.call]
    return fn and function() fn(page) end
end

return setmetatable({
    invenbutton = function(page, a, ctx) return K.InvenButton(page, a.l, a.t, a.r, a.b, a.picture, press(ctx, a, page)) end,
    scrollbar = function(page, a, ctx)
        local fn = ctx.scripts[a.call]
        return K.ScrollBar(page, a.l, a.t, a.b, function(pos) fn(page, pos) end)
    end,
    arrow = function(page, a, ctx) return K.Arrow(page, a.picture, press(ctx, a, page)) end,
    textpane = function(page, a) return K.TextPane(page, a.l, a.t, a.r, a.b) end,
}, { __index = require("interfaces.7x.elements") })
