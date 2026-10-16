-- s6-ui-core (round 85): the elements Modern's XML twin gives its layout files beside the loader's own (core/xml.md,
-- "An interface's own elements"): each makes what the original's Lua makes with Modern's widgets (its skin's UI:
-- core/widgets.lua bound to interfaces/modern/skin.lua), with the same call, so a layout file can say it where the
-- original's code said it. Drawing only.
--   <label text size colour justify parent/>        a plain label (W.Label), on parent when given
--   <button text width height style click/>         a push button; click: the script its OnClick is (W.Button)
--   <iconbutton texture size click/>                a small square glyph button (W.IconButton)
--   <tab name text width height click look icon/>   a tab (W.Tab); look: its colours, a <data> with bg, chosenBg, text
--                                                   and chosenText (@KEY); icon: a picture drawn in it
--   <check text change/>                            a check box with its label; change: the script given the new state
--                                                   (W.Check)
--   <header text width/>                            a centred header between two rules (W.Header)
--   <stepper label step valuewidth size colour/>    a value between < and > buttons; step: the script given -1 or 1
--                                                   (W.Stepper)
--   <editbox width height/>                         a text box (W.EditBox)
--   <panel name parent inner/>                      a panel with the skin's backdrop (W.Panel)
--   <window name title width height/>              a movable window with its title and close box (W.Window)
--   <slotart keys bg edge light inset/>             a slot's picture on its frame (W.SlotArt); keys: where the frame keeps
--                                                   the textures it returns (bg, icon, edge, light; "_" for one not kept);
--                                                   its calls are on the icon
--   <backdrop bg edge bgfile/>                      a frame's backdrop in those colours, on that picture (SetBackdrop)
--   <portrait size point x y colour/>               a unit portrait at point + (x, y) of its frame, its disc in colour
--                                                   (portrait.lua's New)
--   <bar height colour textsize name/>              a health or mana bar (vitals.lua's Bar)
--   <vitalbar height colour textsize name/>         a plain bar with its value text (W.VitalBar)
--   <iconrow name mouse/>                           a group of effect icons (effecticons.lua's NewGroup)
--   <legendlist parent width height/>               a legend's list of marks (W.Character.LegendList); its scroll
--                                                   frame is its .sf
--   <gearslot name x y point/>                      a worn item's slot at point + (x, y) of its frame
--                                                   (W.Character.GearSlot)
--   <figurebox name/>                               a figure's box, its picture .figure (W.Character.FigureBox)
--   <titleband/>                                    the band of light behind a window's title, on its frame (W.TitleBand)
--   <scrollarea content/>                           a scrolling area (W.ScrollArea); its content frame goes on the frame
--                                                   it is made in as content="..."
--   <into>                                          the frame it is made in itself: a template of <into> made by New on a
--                                                   frame that exists fills it (a character window tab's page)
-- A colour is the skin's name for one (white, gold, slotActionEdge...) or its parts ("0.85, 0.85, 0.85"); a parent is
-- a global frame's name or @ref (default the frame the element is in).

local W = require("interfaces.modern.skin").UI

local E = {}

--- A colour attribute: the skin's field of that name, its parts as a list, or false/nil as they are.
local function colour(v)
    if type(v) ~= "string" then return v end
    if v:find(",", 1, true) then
        local c = {}
        for part in v:gmatch("[^,%s]+") do c[#c + 1] = tonumber(part) end
        return c
    end
    return W[v]
end

--- The script a click="..." names (the loading Lua's scripts).
local function script(ctx, name)
    if name == nil then return nil end
    local fn = ctx.scripts and ctx.scripts[name]
    if type(fn) ~= "function" then error(ctx.path .. ": no script function " .. tostring(name), 0) end
    return fn
end

--- A parent attribute: a global frame's name, a frame (@ref), or the frame the element is in.
local function frameOf(v, parent)
    if type(v) == "string" then return _G[v] end
    return v or parent
end

function E.label(parent, a)
    return W.Label(frameOf(a.parent, parent), a.text, a.size, colour(a.colour), a.justify)
end

function E.button(parent, a, ctx)
    return W.Button(parent, a.text, a.width, a.height, a.style, script(ctx, a.click))
end

function E.iconbutton(parent, a, ctx)
    return W.IconButton(parent, a.texture, a.size, script(ctx, a.click))
end

function E.tab(parent, a, ctx)
    local look
    if a.look then
        look = {}
        for k, v in pairs(a.look) do look[k] = colour(v) end
    end
    local opts = (a.name or look or a.icon) and { name = a.name, look = look, icon = a.icon } or nil
    return W.Tab(parent, a.text, a.width, a.height, script(ctx, a.click), opts)
end

function E.check(parent, a, ctx)
    return W.Check(parent, a.text, script(ctx, a.change))
end

function E.header(parent, a)
    return W.Header(parent, a.text, a.width)
end

function E.stepper(parent, a, ctx)
    local opts
    for k, v in pairs({ valueWidth = a.valuewidth, size = a.size, colour = colour(a.colour) }) do
        opts = opts or {}
        opts[k] = v
    end
    return W.Stepper(parent, a.label, script(ctx, a.step), opts)
end

function E.editbox(parent, a)
    return W.EditBox(parent, a.width, a.height)
end

function E.panel(parent, a)
    return W.Panel(frameOf(a.parent, parent), a.name, a.inner)
end

function E.window(_, a)
    return W.Window(a.name, a.title, a.width, a.height)
end

function E.slotart(parent, a)
    local opts
    for _, k in ipairs({ "bg", "edge", "light", "inset" }) do
        if a[k] ~= nil then
            opts = opts or {}
            opts[k] = k == "inset" and a[k] or colour(a[k])
        end
    end
    local made = { W.SlotArt(parent, opts) }
    local i = 0
    for key in (a.keys or ""):gmatch("[^,%s]+") do
        i = i + 1
        if key ~= "_" then parent[key] = made[i] end
    end
    return made[2]
end

function E.backdrop(parent, a)
    parent:SetBackdrop({ bg = colour(a.bg), edge = colour(a.edge), bgFile = a.bgfile })
end

-- (required when first used: portrait.lua loads this file)
function E.portrait(parent, a)
    local c = colour(a.colour)
    return require("interfaces.modern.portrait").New(parent, a.size, a.point, a.x, a.y, c[1], c[2], c[3])
end

function E.bar(parent, a)
    local c = colour(a.colour)
    return require("interfaces.modern.vitals").Bar(parent, a.height, c[1], c[2], c[3], a.textsize, a.name)
end

function E.vitalbar(parent, a)
    local c = colour(a.colour)
    return W.VitalBar(parent, a.height, c[1], c[2], c[3], a.textsize, a.name)
end

function E.legendlist(parent, a)
    return W.Character.LegendList(frameOf(a.parent, parent), a.width, a.height)
end

function E.gearslot(parent, a)
    return W.Character.GearSlot(parent, a.name, a.x, a.y, a.point)
end

function E.figurebox(parent, a)
    return W.Character.FigureBox(parent, a.name)
end

function E.titleband(parent)
    W.TitleBand(parent)
end

function E.scrollarea(parent, a)
    local sf, content = W.ScrollArea(parent)
    if a.content then parent[a.content] = content end
    return sf
end

function E.into(parent)
    return parent
end

function E.iconrow(parent, a)
    return require("interfaces.modern.effecticons").NewGroup(parent, a.name, a.mouse)
end

return E
