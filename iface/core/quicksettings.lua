-- s6-ui-core (round 63; the owner's mock-up): Graphics > General's quick choices use the settings owned by their existing components. No duplicate saved keys:
-- interfaces still switch through Interfaces, styles through graphicsstyles and perspective through WorldRenderers.
local Q = {}
TK.QuickSettings = Q
local R = CS.TK.Modular.Draw.WorldRenderers
local G = CS.TK.Modular.Draw.GraphicsStyles
local function component(name) return TK.GetComponent(name) end

--- Sets a component's existing preference and applies it through its normal settings path.
local function write(name, values, page)
    local c = component(name)
    for key, value in pairs(values) do c:DB()[key] = value end
    c:Changed({ id = page or name })
end

--- The tiles' current drawing style, including the Cycle Graphics Style key's temporary override.
function Q:Tileset()
    return (component("graphicsstyles"):DrawingChoice("tiles"))
end
function Q:SetTileset(value) write("graphicsstyles", { tiles = value }) end

--- Models refers to Asset Styles > Map Objects (the former 3D Map Objects toggle). Low has no implementation yet.
function Q:Models()
    local choice, kind = component("graphicsstyles"):DrawingChoice("map-objects")
    return choice == "custom" and kind == "3d" and "normal" or "off"
end
function Q:SetModels(value)
    if value == "low" then return end
    local c = component("graphicsstyles")
    local db = c:DB()
    -- Compare the saved choice, not the cycle's temporary drawing override. Selecting Off ends that override
    -- without replacing an already saved 2D style or its Custom details.
    local saved = db["map-objects"] or c.defaults["map-objects"]
    local current = saved == "custom" and db["custom:map-objects:kind"] == "3d" and "normal" or "off"
    if value == current then
        if self:Models() ~= value then write("graphicsstyles", {}) end
        return
    end
    -- Entering 3D keeps the current 2D style as its fallback, so Off returns to that style.
    write("graphicsstyles", {
        ["map-objects"] = value == "normal" and "custom" or (db["custom:map-objects:fallback"] or c.defaults["map-objects"]),
        ["custom:map-objects:fallback"] = value == "normal" and saved ~= "custom" and saved or db["custom:map-objects:fallback"],
        ["custom:map-objects:kind"] = value == "normal" and "3d" or "2d",
        ["custom:map-objects:quality"] = "normal",
    })
end

-- Provisional tiers are cumulative data, ready for s6-graphics-bench's measured ordering. Descriptions list everything
-- enabled at each stop. The controls do not store a second copy of any feature; after manual edits the last choice stays
-- shown (the owner's Custom quality indicator is still an open question).
local tiers = {
    { text = "Original Quality", desc = "Added lighting, weather, smoothing, animation interpolation, smooth character movement, Wind Armor Fix and 3D models off. Original 16-bit colours. Interface, tileset and perspective stay selected.",
      settings = { worldview = { smoothMovement = false, smoothing = "none", originalColour16 = true,
                                fadeOver = false, farViewObjects = false, farViewRememberItems = false, zoneBorder = false },
                   graphicsstyles = { windArmorShimmer = false }, interpolation = { enabled = false },
                   character3dtest = { testing = false } }, effects = {} },
    { text = "Basic Cheap Improvements", desc = "Smooth character movement, Wind Armor Fix and full palette colours.",
      settings = { worldview = { smoothMovement = true, originalColour16 = false }, graphicsstyles = { windArmorShimmer = true } }, effects = {} },
    { text = "Smooth and Shadows", desc = "Adds sharp bilinear smoothing and sun shadows.",
      settings = { worldview = { smoothing = "smooth" } }, effects = { lighting = true, sun_shadows = true } },
    { text = "Lighting", desc = "Adds global illumination, real lights and lit doors and windows.",
      settings = {}, effects = { sky_light = true, real_lights = true, door_light = true } },
    { text = "Weather", desc = "Adds wind, rain, snow, lightning and fog.",
      settings = {}, effects = { weather = true, wind = true, rain = true, snow = true, lightning = true, fog = true } },
    { text = "Water and Ground", desc = "Adds wet ground gloss, puddle and water reflections, rain ripples, snow cover and footprints.",
      settings = {}, effects = { wet_gloss = true, puddle_reflections = true, reflections = true, rain_ripples = true,
                               snow_cover = true, footprints = true } },
    { text = "Full Effects", desc = "Adds embers, smoke, fireflies, bloom, dust motes, god rays, lightning silhouettes, heat haze, birds, indoor windows, chimney smoke, moon shadows, height shading, water banks and depth, sun and moon in water, falling leaves, indoor lightning, roof rain and balanced animation interpolation (2 frames). Colour by Hour stays off while global illumination supplies the colours.",
      settings = { interpolation = { enabled = true, method = "balanced", frames = 2 } },
      effects = { embers = true, fireflies = true, bloom = true, dust = true, god_rays = true, silhouettes = true,
                  heat_haze = true, birds = true, indoor_windows = true, chimney_smoke = true, moon_shadows = true,
                  height_shading = true, reflection_banks = true, sky_in_water = true, leaves = true,
                  indoor_lightning = true, roof_rain = true } },
}
Q.presets = tiers
local last = setmetatable({}, { __mode = "k" })

--- Builds a complete table per stop; every added effect is explicitly off until a tier enables it.
function Q:Prepare()
    if self.prepared then return end
    self.prepared = true
    local cumulative, description = {}, ""
    for i, tier in ipairs(tiers) do
        for name, settings in pairs(tier.settings) do
            cumulative[name] = cumulative[name] or {}
            for key, value in pairs(settings) do cumulative[name][key] = value end
        end
        if i == 1 then
            cumulative.advancedeffects = {}
            for key, value in pairs(component("advancedeffects").defaults) do
                if type(value) == "boolean" then cumulative.advancedeffects[key] = false end
            end
        end
        for key, value in pairs(tier.effects) do cumulative.advancedeffects[key] = value end
        tier.settings = TK.Util.Copy(cumulative)
        -- Original alone disables the independent Experimental character test; later stops leave it selected.
        if i == 1 then cumulative.character3dtest = nil end
        if i == 2 then description = tier.desc elseif i > 2 then description = description .. " " .. tier.desc end
        if i > 1 then tier.desc = "Provisional: awaiting graphics cost and benefit research. " .. description end
    end
end

function Q:SetQuality(index)
    self:Prepare()
    local tier = tiers[index]
    if not tier then return end
    -- The effect choices keep the Cycle Graphics Style override, as the Misc page's Wind Armor Fix does.
    for name, values in pairs(tier.settings) do write(name, values, "graphics") end
    -- Only Original removes added models; the other stops leave the mock-up's separate Models choice alone.
    if index == 1 then self:SetModels("off") end
    -- Interpolation observes the existing Advanced Graphics switch; no new master preference is introduced.
    if index == 7 then
        TK.Settings:SetOption("graphicsadvancedgeneral", "advanced", true)
    end
    last[component("worldview"):DB()] = index
end

--- Reflects a preset's existing preferences when edited elsewhere; unmatched manual changes keep the last stop.
function Q:Quality()
    self:Prepare()
    for i, tier in ipairs(tiers) do
        local match = i ~= 1 or self:Models() == "off"
        if i == 7 and not TK.Machine:AdvancedGraphics() then match = false end
        for name, settings in pairs(tier.settings) do
            local c = component(name)
            for key, value in pairs(settings) do
                local actual = c:DB()[key]
                if actual == nil then actual = c.defaults[key] end
                if actual ~= value then match = false end
            end
        end
        if match then return i end
    end
    return last[component("worldview"):DB()] or 1
end

--- s6-ui-core (round 79; interface-separation.md, G2: shared code names no interface): the Interface row's buttons, one
--- per installed interface in the order the player sees them, each with the label and tooltip its own manifest gives
--- (interface.quick; its name when it gives none). Read when the page is built: the registry loads after this file.
local function interfaceChoices()
    local out = {}
    for _, interface in ipairs(TK.Interfaces:InOrder()) do
        local quick = interface.quick or {}
        out[#out + 1] = { value = interface.id, text = quick.text or interface.name or interface.id, desc = quick.desc }
    end
    return out
end

--- The mock-up's five rows at the top of Graphics > General, drawn with the settings window's shared controls.
function Q:Rows()
    return {
        { type = "header", name = "Quick Settings" },
        { type = "oneof", name = "Interface", width = "full", machine = true, values = interfaceChoices,
          get = function() return TK.Interfaces:Active().id end, set = function(_, v) TK.Interfaces:SwitchTo(v) end },
        { type = "oneof", name = "Tileset", width = "full", machine = false,
          values = { { value = "2d-7x", text = "7.5", desc = "The 7.5 tiles." },
                     { value = "2d-5x", text = "Retro (v5)", desc = "The Retro 5.x tiles." },
                     { value = "custom", text = "Custom", desc = "Uses the Tiles choices on Graphics > Asset Styles." } },
          get = function() return Q:Tileset() end, set = function(_, v) Q:SetTileset(v) end },
        { type = "oneof", name = "Perspective", width = "full",
          values = { { value = "reprojection:3d", text = "3D", desc = "The 3D world view." },
                     { value = "reprojection:3d-sphere", text = "3D-Sphere", desc = "The curved 3D world view." },
                     { value = "normal", text = "2D (Flat)", desc = "The original flat 2D world view." } },
          get = function() return R.Choice end, set = function(_, v) R.Choose(v) end },
        { type = "range", name = "Quality", width = "full", machine = false, min = 1, max = 7, step = 1,
          sections = function() Q:Prepare() return tiers end,
          get = function() return Q:Quality() end, set = function(_, v) Q:SetQuality(v) end },
        { type = "oneof", name = "Models (3D Only)", width = "full", machine = false,
          values = { { value = "off", text = "Off", desc = "Draw map objects with their 2D fallback." },
                     { value = "normal", text = "Normal", desc = "Use normal 3D map object models where available." },
                     { value = "low", text = "Low", disabled = true, desc = "Not built yet." } },
          requires = { TK.Needs("Perspective: 3D or 3D-Sphere", function() return R.Choice == "reprojection:3d" or R.Choice == "reprojection:3d-sphere" end) },
          get = function() return Q:Models() end, set = function(_, v) Q:SetModels(v) end },
        { type = "header", name = "Display" },
    }
end

return Q
