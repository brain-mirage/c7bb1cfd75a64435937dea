-- s6-modular: the Graphics Styles page. One choice per category, listing the installed drawing modules that serve it
-- (their manifests, read without loading them). The choices belong to the profile and apply at once; a module no
-- category chooses any more is not loaded, or gives back its art. What a chosen style has no picture for is drawn
-- Modern: a unit at a time (a tile, an icon, a map object piece, a monster's look, a figure's layer), as the module says.

local C = TK.GetComponent("graphicsstyles")
local G = CS.TK.Modular.Draw.GraphicsStyles

-- s6-modular-g: in the settings window's three tabs (s6-ui-settings) a General page, as Graphics is: it sets up the
-- drawing, not one piece of the interface (a component's page is an Interface page unless it says otherwise).
C.category = "general"
-- s6-ui-core (round 54; the owner, 2026-10-05): "Asset Styles" (the manifest's title), a subpage of Graphics after its
-- General (core/settings.lua's GENERAL_ORDER). The keys are the same, so saved choices carry over.
C.parent = "Graphics"
-- s6-ui-core (round 54): at the login screen too, as Graphics' other pages (the Looks, here until round 83, are on the
-- Interface page now, which is there too).
C.atLogin = true

C.categories = {
    { key = "tiles", name = "Tiles" },
    { key = "map-objects", name = "Map Objects" },
    { key = "items", name = "Items" },
    { key = "monsters", name = "Monsters" },
    { key = "npcs", name = "NPCs" },
    { key = "characters", name = "Characters" },
    { key = "mounts", name = "Mounts" },
    { key = "effects", name = "Effects" },
}

C.defaults = {}
for _, c in ipairs(C.categories) do C.defaults[c.key] = "2d-7x" end

local function choices(category)
    return function()
        local list = {}
        for id, name in string.gmatch(G.Choices(category), "([^=;]+)=([^;]*)") do
            list[#list + 1] = { value = id, text = name }
        end
        return list
    end
end

-- s6-ui-core (round 54): the drawing styles, the modules whose manifests make them modes of the Cycle Graphics Style key
-- (Modern, then Retro: GraphicsStyles.CycleStyles), { id, name, options }; main.lua's modes are these after User.
C.styles, C.isStyle = {}, {}
for line in string.gmatch(G.CycleStyles(), "[^\n]+") do
    local id, name, options = string.match(line, "^([^|]*)|([^|]*)|(.*)$")
    if id then
        local s = { id = id, name = name, options = {} }
        for key, value in string.gmatch(options, "([^=;]+)=([^;]*)") do s.options[key] = value end
        C.styles[#C.styles + 1] = s
        C.isStyle[id] = s
    end
end

-- s6-ui-core (round 54; the owner, 2026-10-05: "each category ... offers Modern, Retro or Custom. Choosing Custom shows
-- two dropdowns side by side right under that setting ... 2D / 3D and Normal / HD", and the head's "Fallback: Modern /
-- Retro"): a category's choices are the styles that serve it, then Custom. Custom's own choices are kept under
-- s6-reprojection's keys (its FOR note): custom:<category>:kind, :quality and :fallback. Its drawing is main.lua's
-- C:SelectCustom.
local function styleChoices(category)
    return function()
        local list = {}
        for _, s in ipairs(C.styles) do
            if G.Serves(s.id, category) then list[#list + 1] = { value = s.id, text = s.name } end
        end
        list[#list + 1] = { value = "custom", text = "Custom" }
        return list
    end
end
local KINDS = { { value = "2d", text = "2D" }, { value = "3d", text = "3D" } }
local QUALITIES = { { value = "normal", text = "Normal" }, { value = "hd", text = "HD" } }
local FALLBACKS = {}
for _, s in ipairs(C.styles) do FALLBACKS[#FALLBACKS + 1] = { value = s.id, text = "Fallback: " .. s.name } end
for _, c in ipairs(C.categories) do
    C.defaults["custom:" .. c.key .. ":kind"] = "2d"
    C.defaults["custom:" .. c.key .. ":quality"] = "normal"
    C.defaults["custom:" .. c.key .. ":fallback"] = C.defaults[c.key]
end

-- s6-ui-core (build 41; the owner, 2026-10-05): Allow Switching During Gameplay (s6-modular rounds 13 and 16), which stood
-- at this page's top, is gone: the Experimental tab's pages change in the game too, and only the chosen world renderer is
-- ever loaded (TK.Modular.Draw.WorldRenderers).
local args = { { type = "header", name = "Drawing Style" } }
for _, c in ipairs(C.categories) do
    local arg = { type = "stylechoice", key = c.key, name = c.name, values = styleChoices(c.key), extrasWhen = "custom",
                  extras = { { key = "custom:" .. c.key .. ":kind", values = KINDS },
                             { key = "custom:" .. c.key .. ":quality", values = QUALITIES },
                             { key = "custom:" .. c.key .. ":fallback", values = FALLBACKS } } }
    -- s6-modular-b (round 14; Astra's P3 on round 13): the 3D module serves only Characters and no menu offers it, but a
    -- profile from before round 13 may still hold it. The drop-down shows that choice as it is drawn, Modern
    -- (GraphicsStyles.Shown), and the profile keeps it until the player chooses again. The setter is the page's usual
    -- write; a getter alone would take the control out of the page's reset.
    if c.key == "characters" then
        arg.get = function() return G.Shown(C:DB()[c.key] or C.defaults[c.key]) end
        arg.set = function(node, v)
            C:DB()[c.key] = v
            C:Changed(node, c.key, v)
        end
    end
    args[#args + 1] = arg
end
-- s6-characters (round 41; the owner, 2026-10-04): the 7.5.2 Wind armor's 5.x shimmer, on by default
-- (CS.TK.Objects.PaletteOverrides; applied in main.lua): the warrior's Wind platemail (and its dress) in its blue dye
-- ripples as in the 5.x clients, in the Modern drawing too; off, it is still and blue, as 7.5.2 draws it. Nothing is sent.
-- s6-ui-core (build 41; the owner, 2026-10-05): it is the Experimental tab's Misc page's "Wind Armor Fix" now
-- (core/settings.lua, TK.MiscNode), with no description, the same key, so a saved choice carries over.
C.defaults.windArmorShimmer = true
local misc = TK.MiscNode.tabs[1].args
misc[#misc + 1] = { type = "toggle", name = "Wind Armor Fix", default = true,
    get = function() return C:DB().windArmorShimmer ~= false end,
    set = function(node, v)
        C:DB().windArmorShimmer = v and true or false
        C:Changed(node, "windArmorShimmer", v)
    end }

-- The installed modules' own options (their manifests), a choice each under "option:<module>:<key>", the first value the
-- default; the Retro figures' "whole" or "per part" is one. s6-ui-core (round 54): an option whose manifest names another
-- page (its "page": the world view's, for Retro World View) is listed there (C:OptionsFor), with the same key here.
C.options = {}
local styleOptions = 0
for line in string.gmatch(G.Options(), "[^\n]+") do
    local module, key, name, values, page = string.match(line, "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
    if module then
        local o = { module = module, key = key, name = name, page = page ~= "" and page or nil,
                    db = "option:" .. module .. ":" .. key, values = {} }
        for value, text in string.gmatch(values, "([^=;]+)=([^;]*)") do
            o.values[#o.values + 1] = { value = value, text = text }
            o.default = o.default or value
        end
        if o.default then
            C.options[#C.options + 1] = o
            C.defaults[o.db] = o.default
            -- s6-ui-core (round 54): the option naming the style its module draws over (its manifest's "over": 3D map
            -- objects' Objects Without a 3D Model) is Custom's Fallback (main.lua). The page lists only the styles' own
            -- options; a module that is not a style is Custom's.
            o.over = G.OverOption(module) == key
            if not o.page and C.isStyle[module] then
                styleOptions = styleOptions + 1
                if styleOptions == 1 then args[#args + 1] = { type = "header", name = "Style Options" } end
                args[#args + 1] = { type = "select", key = o.db, name = name, values = o.values }
            end
        end
    end
end

--- s6-ui-core (round 54): the modules' options another page lists (an option's manifest "page"), as that page's selects:
--- kept here under their keys (saved profiles keep them) and applied as this page's; each needs its module drawing the
--- Tiles now (the style drawn, the Cycle Graphics Style key's included: Astra's review), its (!) otherwise.
function C:OptionsFor(page)
    local out, names = {}, {}
    for _, c in ipairs(choices("tiles")()) do names[c.value] = c.text end
    for _, o in ipairs(self.options) do
        if o.page == page then
            out[#out + 1] = { type = "select", name = o.name, values = o.values,
                get = function() return C:DB()[o.db] or o.default end,
                set = function(node, v)
                    C:DB()[o.db] = v
                    C:Changed(node, o.db, v)
                end,
                default = function() return o.default end,
                requires = { TK.Needs("Asset Styles > Tiles: " .. (names[o.module] or o.module),
                    function() return G.Selected("tiles") == o.module end) } }
        end
    end
    return out
end

-- s6-ui-core (round 54; the owner, 2026-10-05: "condense that into 3 single lines, succinct, that describe each of the 3
-- options", each ending with a "?" and a very short tooltip). They replace s6-modular-d's and s6-modular-b's two long
-- paragraphs (the Retro rules, the Mixed heads, the 3D test, the old world view's sizes).
-- s6-ui-core (round 83; the owner, 2026-10-09: "If it makes sense move it for now and I'll decide later"): the Looks
-- (Dialogs and Cursors), here since round 54, are the General tab's Interface page's Looks tab now
-- (components/interface/settings.lua), the same profile values.

args[#args + 1] = { type = "header", name = "The Styles" }
args[#args + 1] = { type = "description", name = "Modern: the 7.5.2 client's own art.", help = "As the live client draws it." }
args[#args + 1] = { type = "description", name = "Retro: the old art where it exists, Modern elsewhere.",
    help = "As the 2026 client's Classic mode. A mounted figure follows its rider." }
args[#args + 1] = { type = "description", name = "Mixed: Retro with the 2003 heads (Retro Characters).",
    help = "Retro Characters can also draw the 2003 figures whole." }
args[#args + 1] = { type = "description", name = function()
    local p = G.Problems()
    return p ~= "" and ("Problems:\n" .. p) or ""
end }

C.tabs = { { name = "Asset Styles", args = args } }
