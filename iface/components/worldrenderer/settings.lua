-- s6-modular (round 13; the owner, 2026-10-03): the Experimental tab's page, the world renderer: Normal (the client's own
-- drawing, the default) or a mode of an installed renderer module, and the options the chosen one declares. A choice
-- switches the world's drawing at the next frame. Nothing is sent. s6-ui-core (build 41; the owner, 2026-10-05): at the
-- login screen and in the game alike; Allow Switching During Gameplay, which loaded every renderer so that the game could
-- switch, is gone (TK.Modular.Draw.WorldRenderers loads the chosen one at the switch).

local C = TK.GetComponent("worldrenderer")
local R = CS.TK.Modular.Draw.WorldRenderers

local function pairsOf(values)
    local list = {}
    for value, text in string.gmatch(values, "([^=;]+)=([^;]*)") do list[#list + 1] = { value = value, text = text } end
    return list
end

-- s6-reprojection (round 34; the owner, 2026-10-06, Graphics > General's View Distance; the head's notes view-distance-fade,
-- view-distance-start and view-distance-slider-owner): a renderer's "viewdistance" option (module.json) as s6-ui-core's one
-- slider (round 60) with two handles under one key, "view,end": cells past the edge of what the game draws round the player
-- (the reprojection module's Distance.Edge: the live area, or the outer area while there is one), "off" at the slider's Off
-- stop. The left handle is the View Distance; the right where the fade out ends, its box showing it past the left, turned on
-- and off by the box of the option it needs (Fade Out, `toggle`). A step apart, the one pushing the other. Round 35: a value
-- saved before round 34 (one number, from the player) comes from R.Option already as its pair (the host's ModuleOption.Read),
-- so the slider shows and edits it at the login screen too.
local OFF = -1 -- the Off stop's value on the slider ("off" in the option)
local function viewDistance(module, key, toggle, arg)
    local function part(v, i)
        local text = select(i, string.match(v or "", "^([^,]*),(.*)$"))
        return text == "off" and OFF or tonumber(text)
    end
    local function value(i) return part(R.Option(module, key), i) or part(R.OptionDefault(module, key), i) end
    local function text(n) return n == OFF and "off" or string.format("%g", n) end
    local function handle(i)
        return {
            get = function() return value(i) end,
            set = function(_, v)
                local p = { value(1), value(2) }
                p[i] = v
                R.SetOption(module, key, text(p[1]) .. "," .. text(p[2]))
            end,
            default = function() return part(R.OptionDefault(module, key), i) end,
        }
    end
    -- s6-ui-core (round 62; the owner's spec, the head's note view-distance-row): Fade Out's box right of the slider, and the
    -- Off stop only while Fade Out is off (with it on the slider ends at its maximum): the one slider's own options
    arg.type, arg.gap, arg.stop = "range", arg.step, { text = "Off", value = OFF, onlyWithout = 2 }
    arg.togglesBeside = true
    arg.get, arg.set, arg.default = nil, nil, nil
    arg.handles = { handle(1), handle(2) }
    arg.handles[2].relative = 1
    arg.handles[2].toggle = toggle
end

-- The chosen renderer's options for its mode, a control each, read and set through the host (kept in modules.json).
-- s6-reprojection (round 30): those of one page (nil: this page's, the options naming no page of their own); an option
-- that needs a toggle on (the manifest's "needs") has the settings' (!) rule while it is off (round 31, s6-ui-core's
-- round 56 note: usable, its title grey, the (!) naming the toggle). Round 34: each option's tooltip (the manifest's
-- "desc"), and a View Distance slider whose fade handle the option it needs turns on and off (viewDistance).
local function addOptions(args, page)
    local module = string.match(R.Choice, "^([^:]+):")
    -- Round 36, owner's requested pair: retain its controls greyed in Normal, using the manifest's own text/defaults.
    -- Round 44 (the owner, 2026-10-08): Other Figures Turn With Camera joins them, greyed in Normal the same way.
    local inactive = not module
    module = module or "reprojection"
    local options = inactive and R.OptionsFor(module, "3d", page) or R.OptionsOn(page)
    local function facing(key) return key == "3d-turn-figures" or key == "3d-turn-others" or key == "3d-forward-facing" end
    local pattern = "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$"
    local names = {} -- each option's name by its key, for the (!)
    for line in string.gmatch(options, "[^\n]+") do
        local key, _, name = string.match(line, pattern)
        if key then names[key] = name end
    end
    local byKey, besides = {}, {}
    for line in string.gmatch(options, "[^\n]+") do
        local key, kind, name, values, min, max, step, needs, desc = string.match(line, pattern)
        if not inactive or facing(key) then
            local function read(v)
                if kind == "range" then return tonumber(v) end
                if kind == "toggle" then return v == "true" end
                return v
            end
            local arg = { type = kind, name = name, desc = desc ~= "" and desc or nil,
                          get = function() return read(R.Option(module, key)) end,
                          set = function(_, v) R.SetOption(module, key, tostring(v)) end,
                          default = function() return read(R.OptionDefault(module, key)) end }
            if kind == "viewdistance" then
                arg.min, arg.max, arg.step = tonumber(min), tonumber(max), tonumber(step)
                besides[arg] = { key = key, needs = needs }
            else
                if needs ~= "" then
                    arg.requires = { TK.Needs(names[needs] or needs, function() return R.Option(module, needs) == "true" end) }
                end
                if kind == "range" then
                    arg.min, arg.max, arg.step = tonumber(min), tonumber(max), tonumber(step)
                elseif kind ~= "toggle" then
                    arg.type, arg.values = "select", pairsOf(values)
                end
            end
            if facing(key) then arg.disabled = function() return inactive end end
            if key == "3d-turn-figures" then args[#args + 1] = { type = "break" } end
            byKey[key] = arg
            args[#args + 1] = arg
            if key == "3d-forward-facing" then args[#args + 1] = { type = "break" } end
        end
    end
    -- round 34: a View Distance's switch out of the list, into the slider as its fade handle's box
    for distance, o in pairs(besides) do
        local switch = byKey[o.needs]
        for i = #args, 1, -1 do
            if args[i] == switch then table.remove(args, i) end
        end
        viewDistance(module, o.key, switch, distance)
    end
end

function C:SettingsNodes()
    local args = { { type = "description", name = "Experimental: what is on this tab may change or go." } }
    args[#args + 1] = { type = "select", name = "World Renderer", values = function() return pairsOf(R.Choices()) end,
                        get = function() return R.Choice end, set = function(_, v) R.Choose(v) end, default = "normal" }
    addOptions(args)
    args[#args + 1] = { type = "description", name = function()
        local p = R.Problems()
        return p ~= "" and ("Problems:\n" .. p) or ""
    end }
    -- s6-reprojection (round 30; the owner, 2026-10-05: "make sure any settings related to this go under Experimental >
    -- Skybox"): the 3D views' sky, the horizon the map shapes and the ground past its edge (the renderer's options that
    -- name this page)
    local sky = { { type = "description", name = "3D views only." } }
    addOptions(sky, "skybox")
    -- s6-reprojection (round 34; the owner, 2026-10-06: "For graphics general if there is a view/draw distance move it here.
    -- I want a seperator on this page that seperate the existing stuff thiss seperateor is labeled 3D"): Graphics >
    -- General's 3D section, the renderer's options that name the page "graphics" under a "3D" separator, after the page's
    -- own (core/settings.lua's TK.GraphicsNode); made again here each time the pages are listed, as the renderer chosen
    -- may have changed (none with Normal)
    local general = TK.GraphicsNode.tabs[1].args
    for i = #general, 1, -1 do
        if general[i].renderer then table.remove(general, i) end
    end
    local three = {}
    addOptions(three, "graphics")
    if #three > 0 then table.insert(three, 1, { type = "header", name = "3D" }) end
    for _, a in ipairs(three) do
        a.renderer = true
        general[#general + 1] = a
    end
    return { {
        id = "worldrenderer", title = "World Renderer", order = self.order, category = "experimental", atLogin = true,
        tabs = { { name = "World Renderer", args = args } },
    }, {
        id = "skybox", title = "Skybox", order = self.order + 0.5, category = "experimental", atLogin = true,
        tabs = { { name = "Skybox", args = sky } },
    } }
end
