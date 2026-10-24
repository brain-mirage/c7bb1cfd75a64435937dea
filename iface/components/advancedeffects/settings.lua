-- s6-effects (round 1; the owner, 2026-10-03; docs/user-related/research/advanced-weather-and-lighting.md 8): the
-- Experimental tab's Advanced Weather and Advanced Lighting pages. Every switch is off by default but Lightning (on:
-- docs/user-related/decisions/2026-10-03-effects-defaults.md), and each page's master switch greys out what is under it.
-- They are drawing preferences, so they are saved in the profile; main.lua applies them. At the login screen and in the
-- game (a change shows at the next frame).
-- s6-ui-core (round 60; the owner, 2026-10-06): the pages are Graphics > Advanced > Lighting and Weather now (listed
-- after Motion by core/settings.lua's S.places), each master switch hides the page's group, a feature's sub-features are
-- a group under it, and the explanations are the rows' tooltips. The keys and their stored values are as they were;
-- nothing a switch does has changed.

local C = TK.GetComponent("advancedeffects")

C.defaults = { weather = false, transition = 30, wind = false, wind_sound = 50, lighting = false,
               sky_light = false, real_lights = false, sun_shadows = false } -- s6-effects-c: Advanced Lighting's switches
C.defaults.rain, C.defaults.snow, C.defaults.rain_sound = false, false, 50 -- s6-effects-b: the new rain and snow, the rain's sound
C.defaults.lightning, C.defaults.thunder_sound = true, 50 -- s6-effects (round 2): the lightning, on by default, and its thunder
C.defaults.fog = false -- s6-effects (round 3): the low mist
C.defaults.wet_gloss, C.defaults.puddle_reflections = false, false -- s6-effects (round 4, the owner): the wet ground's additions
C.defaults.rain_ripples = false -- s6-effects (round 6): the rain's rings, a child of the Rain Shader
C.defaults.embers, C.defaults.fireflies, C.defaults.bloom, C.defaults.dust = false, false, false, false -- s6-effects-c: the lighting's extras
C.defaults.god_rays, C.defaults.silhouettes, C.defaults.reflections, C.defaults.heat_haze = false, false, false, false -- s6-effects-c (round 4): more extras
C.defaults.colour_by_hour, C.defaults.birds = false, false -- s6-effects-c (round 5): the last extras
C.defaults.indoor_windows = false -- s6-effects-c (round 6)
C.defaults.chimney_smoke = false -- s6-effects (round 8): Embers and Smoke's child
C.defaults.moon_shadows, C.defaults.height_shading = false, false -- s6-effects-c (round 8): Sun Shadows' children
C.defaults.reflection_banks, C.defaults.sky_in_water = false, false -- s6-effects-c (round 8): Water Reflections' children
C.defaults.snow_cover, C.defaults.footprints, C.defaults.leaves = false, false, false -- s6-effects-b (round 2): phase 5's extras
C.defaults.max_snow_cover = 100 -- s6-reprojection-cloud-3 (the owner, 2026-10-21): the most snow cover drawn, %
C.defaults.wind_speed = { 0.6, 3.3 } -- s6-effects (round 11, the owner): the sway's speed range, tiles a second (TK.Core.Map.WindSway)
C.defaults.indoor_lightning, C.defaults.roof_rain = false, false -- s6-effects (round 12): the storm outside heard and seen indoors
C.defaults.door_light = false -- s6-effects (round 12): light from the buildings' doorways and windows at night

-- What greys a control out (s6-effects round 4: what each one's description says it needs). A child sits right under
-- its parent and is greyed until the parent is on, as Max Snow Cover under Snow Cover (the owner, 2026-10-04:
-- sub-options "so you can 'add to it' if it's enabled"): the page's master switch; the thunder the Lightning switch;
-- Bloom and Dust Motes a light to work with (Global Illumination or Real Lights); the silhouettes a positional flash
-- (Lightning, on the other page, and Global Illumination); Colour by Hour Global Illumination off (it colours by the
-- hour itself).
-- s6-ui-core (round 54; the owner's rule for every settings page, 2026-10-05): these were disabled conditions; now each
-- control names what it needs (TK.Needs, core/settings.lua) and stays usable, its value kept, with a (!) after its title
-- while it is on and a need is unmet. Both pages read one settings table, so a need on the other page names it.
-- s6-ui-core (round 60; the owner, 2026-10-06: "When Enable advanced lighting is disable hide all the options that require
-- it. Clicking it shows the options."; and, by the head's note, declared needs and groups): a need on a setting of the
-- page names its key and state (TK.NeedSetting; the (!) names the setting by its name here); the two master switches'
-- hide their page's group; the others still mark (!). A need on the other page, or on two settings, is written out.
local weather = TK.NeedSetting("weather", true, "hide")
local windShader = TK.NeedSetting("wind") -- s6-effects (round 11): Sway Speed is its
local snowCover = TK.NeedSetting("snow_cover") -- s6-effects-b: Max Snow Cover caps it
local rainShader = TK.NeedSetting("rain") -- s6-effects (round 6): the ripples ring its rain
local lightning = TK.NeedSetting("lightning") -- as main.lua reads it: on unless off (a profile always has it: its default)
local lighting = TK.NeedSetting("lighting", true, "hide") -- s6-effects-c
local embers = TK.NeedSetting("embers") -- s6-effects (round 8): the chimneys' smoke
local aLight = TK.Needs("Global Illumination or Real Lights", function(db) return db.sky_light or db.real_lights end)
local skyLight = TK.NeedSetting("sky_light")
local noSkyLight = TK.NeedSetting("sky_light", false) -- it colours by the hour itself
local sunShadows = TK.NeedSetting("sun_shadows") -- s6-effects-c (round 8): its children
local reflections = TK.NeedSetting("reflections") -- s6-effects-c (round 8): its children
-- the silhouettes' positional flash: Lightning on the other page (s6-ui-core round 60: the page is Weather now).
-- s6-ui-core (round 60; s6-optimize's FOR r60, item 2): made once here for every page that needs them (Sound > Advanced's
-- Positional Lightning Sounds too, components/audio/settings.lua), so they read this component's table, not the page's.
C.weatherNeed = TK.Needs("Weather > Enable Advanced Weather Effects", function() return C:DB().weather end)
C.lightningNeed = TK.Needs("Weather > Lightning", function() return C:DB().lightning ~= false end)
-- s6-ui-core (round 60; s6-optimize's FOR r60, item 1; the owner: "dependencies for stuff including any text"): the light
-- buffer that Global Illumination, Real Lights and what needs them draw from is made only with the original's Shadows
-- option on (MapRenderer.FollowLightBuffer). The option is the World View page's; it was only said in two tooltips. Its
-- page is Graphics' World View since round 83 (s6-ui-core round 84: the head's final review of round 83).
local shadows = TK.Needs("Graphics > World View > Shadows", function() return TK.GetComponent("worldview"):DB().shadows ~= false end)

-- s6-ui-core (round 60): the Experimental tab's notice, in the master switches' tooltips now
local EXPERIMENTAL = "Experimental: it may change or go. "

-- s6-effects (round 4): the two pages as a player meets them, from three jobs' switches (s6-effects', s6-effects-b's rain,
-- snow and leaves, s6-effects-c's lighting): the page's master switch and what it brings with it first, then the effects
-- in groups under headers, each effect's switch before its sound and its children, and one voice in the descriptions
-- (what you see or hear, and when). The keys and their stored values are as they were.
-- s6-ui-core (round 60; the owner, 2026-10-06: "Remove descripotions to tool tips and organze the setitngs on this page to
-- be grouped with each other based on type. Also If there are subfeatures under advanced lighting like lets say global
-- illumatnion and then there are effects that rely on that they should be grouped under that one"): labels and controls
-- only, each explanation its row's tooltip (desc); the groups by type, one control a row, each feature's sub-features
-- right under it a step in. Each page's body is a group under its master switch (one control a row), and a feature's
-- sub-features a group under it, needing it. To move an effect to another group, move its line (and its sub-features'
-- group) under that group's header.
function C:SettingsNodes()
    local function node(id, title, order, args)
        return { id = id, title = title, order = order, category = "experimental", atLogin = true,
                 db = function() return self:DB() end, defaults = function() return self.defaults end,
                 tabs = { { name = title, args = args } } }
    end
    return {
        node("advancedweather", "Weather", self.order, {
            { type = "toggle", key = "weather", name = "Enable Advanced Weather Effects",
              desc = EXPERIMENTAL .. "Weather of its own over the server's: clouds, spells of rain, wind, storms and wet ground, the same on every computer at once. Nothing is sent: the server sees no difference." },
            { type = "group", requires = { weather }, indent = 0, args = { -- s6-ui-core (round 60): the page's body
                { type = "range", key = "transition", name = "Transition (seconds)", min = 0, max = 300, step = 5,
                  desc = "How long the weather takes to change where you stand. A new map shows its weather at once." },

                { type = "header", name = "Wind" },
                { type = "toggle", key = "wind", name = "Wind Shader",
                  desc = "Trees, bushes and tall plants sway with the wind: almost still on a fair day, strongly in a storm." },
                { type = "group", requires = { windShader }, args = {
                    -- s6-effects (round 11, the owner: "a min and max ... You should be able to set it VERY slow")
                    { type = "dualrange", key = "wind_speed", name = "Sway Speed (tiles a second)", min = 0.3, max = 5, step = 0.1,
                      desc = "How fast the sway crosses the trees: left in the lightest wind, right in the strongest." },
                } },
                { type = "range", key = "wind_sound", name = "Wind Sound Volume", min = 0, max = 100, step = 5,
                  desc = "The wind's rush, rising with the wind and its gusts (0 is off)." },
                { type = "toggle", key = "leaves", name = "Falling Leaves", -- s6-effects-b
                  desc = "The wind takes leaves off the trees, more in a gust; a flowering tree drops petals." },

                { type = "header", name = "Rain" }, -- s6-effects-b's switches, grouped by s6-effects (round 4)
                { type = "toggle", key = "rain", name = "Rain Shader", -- s6-effects-b
                  desc = "New rain in place of the original's: light or heavy, leaning in the wind, splashing, darker at night." },
                { type = "group", requires = { rainShader }, args = {
                    { type = "toggle", key = "rain_ripples", name = "Rain Ripples", -- s6-effects (round 6)
                      desc = "Raindrops ring the water and the filled puddles. Needs the Rain Shader." },
                } },
                { type = "range", key = "rain_sound", name = "Rain Sound Volume", min = 0, max = 100, step = 5, -- s6-effects-b
                  desc = "The rain's patter, louder as the rain grows (0 is off)." },
                { type = "toggle", key = "roof_rain", name = "Rain on the Roof", -- s6-effects (round 12)
                  desc = "Indoors, a gentle patter on the roof while it rains outside." },

                { type = "header", name = "Snow" },
                { type = "toggle", key = "snow", name = "Snow Shader", -- s6-effects-b
                  desc = "New snow in place of the original's: flakes near and far, carried by the wind, thicker in a blizzard." },
                { type = "toggle", key = "snow_cover", name = "Snow Cover", -- s6-effects-b
                  desc = "While it snows, the ground, roofs, walls and trees whiten, melting after it stops. None on water." },
                -- s6-reprojection-cloud-1 (run 20; open question 111, answered "follow Footprints alone"): out of Snow
                -- Cover's group, so the prints on sand need only this switch; those in snow need snow lying
                { type = "toggle", key = "footprints", name = "Footprints", -- s6-effects-b
                  desc = "Walking figures leave prints in snow (with Snow Cover) and on sand, fading after a while." },
                { type = "group", requires = { snowCover }, args = {
                    { type = "range", key = "max_snow_cover", name = "Max Snow Cover", min = 0, max = 100, step = 5, -- s6-reprojection-cloud-3
                      desc = "The most snow that lies, in %. Lower makes heavy snow patchier; 0 lets none lie. Needs Snow Cover." },
                } },

                { type = "header", name = "Wet Ground", -- s6-effects (round 4, the owner): the wet ground's children
                  desc = "While it rains the ground darkens and puddles fill; both dry after. These add to them." },
                { type = "toggle", key = "wet_gloss", name = "Wet Ground Gloss",
                  desc = "Wet ground catches the light: a faint sheen by day, a glint in a lightning flash." },
                { type = "toggle", key = "puddle_reflections", name = "Puddle Reflections",
                  desc = "Figures, trees and buildings are mirrored in the puddles, rippling." },

                { type = "header", name = "Storms" },
                { type = "toggle", key = "lightning", name = "Lightning",
                  desc = "Flashes in heavy rain, the same strikes on every computer. With Global Illumination (Lighting) a strike lights the world from its side. Turn it off if flashing light troubles you." },
                { type = "group", requires = { lightning }, args = {
                    { type = "range", key = "thunder_sound", name = "Thunder Sound Volume", min = 0, max = 100, step = 5,
                      desc = "The thunder after each flash: sooner and louder when near (0 is off). From the strike's side with Sound > Advanced's Positional Lightning Sounds." },
                    { type = "toggle", key = "indoor_lightning", name = "Lightning Indoors", -- s6-effects (round 12)
                      desc = "Indoors, the storm outside is heard muffled and flashes at the windows and doorways." },
                } },

                { type = "header", name = "Mist" },
                { type = "toggle", key = "fog", name = "Fog and Mist", -- s6-effects (round 3)
                  desc = "A low mist over the land at dawn on some days, and while the ground dries after rain." },
            } },
        }),
        node("advancedlighting", "Lighting", self.order + 1, {
            { type = "toggle", key = "lighting", name = "Enable Advanced Lighting",
              desc = EXPERIMENTAL .. "Light and shadow of their own over the game's night and lights. Nothing is sent: the server sees no difference." },
            { type = "group", requires = { lighting }, indent = 0, args = { -- s6-ui-core (round 60): the page's body
                { type = "header", name = "Shadows" }, -- s6-effects-c's switches (phases 4a, 4b and 4c)
                -- s6-ui-core (round 57; s6-optimize's FOR r56, item 3): the text follows the decision
                -- docs/user-related/decisions/2026-10-05-every-painted-shadow-goes.md (every painted shadow goes, walls cast)
                { type = "toggle", key = "sun_shadows", name = "Sun Shadows", -- s6-effects-c
                  desc = "Everything with a painted shadow casts its own from the sun instead, long at dawn and dusk, short at noon. The painted shadows are gone while it is on, at every hour (at night only Moon Shadows casts any)." },
                -- s6-effects-c (round 8, the owner's effects parity): Sun Shadows' children, the 3D modes' moon shadows and bumps in Normal
                { type = "group", requires = { sunShadows }, args = {
                    { type = "toggle", key = "moon_shadows", name = "Moon Shadows", -- s6-effects-c (round 8)
                      desc = "At night the moon casts the sun's shadows, as strong as it is full. None indoors or where a map is dark." },
                    { type = "toggle", key = "height_shading", name = "Height Shading", -- s6-effects-c (round 8)
                      desc = "Bumpy ground (cobbles, mounds) is shaded by the sun, as the 3D view raises it." },
                } },

                { type = "header", name = "Light" },
                { type = "toggle", key = "sky_light", name = "Global Illumination", requires = { shadows }, -- s6-effects-c
                  desc = "The sky's light colours the world by the hour, storms darken it, and light stops at walls. Nights and caves stay as dark as the game draws them." },
                { type = "group", requires = { skyLight }, args = {
                    { type = "toggle", key = "silhouettes", name = "Lightning Silhouettes", requires = { C.weatherNeed, C.lightningNeed }, -- s6-effects-c
                      desc = "In a storm, figures and trees flash into hard shadows as lightning strikes from the side. Needs Weather's Lightning." },
                } },
                -- Global Illumination's alternative, beside it (the head's brief, round 60)
                { type = "toggle", key = "colour_by_hour", name = "Colour by Hour", requires = { noSkyLight }, -- s6-effects-c (round 5)
                  desc = "With Global Illumination off, a light grade by the hour: a warm dawn, a golden dusk, a blue night." },
                { type = "toggle", key = "real_lights", name = "Real Lights", requires = { shadows }, -- s6-effects-c
                  desc = "Lanterns, candles, torches and fires give coloured, flickering light where it is dark." },

                -- what needs Global Illumination or Real Lights, after both (the head's brief, round 60), its header too; and
                -- the Shadows option, as they draw from the same light buffer (a group's needs reach only its own rows)
                { type = "group", requires = { aLight, shadows }, indent = 0, args = {
                    { type = "header", name = "With Global Illumination or Real Lights" },
                    { type = "toggle", key = "bloom", name = "Bloom", -- s6-effects-c
                      desc = "A soft glow round bright lights." },
                    { type = "toggle", key = "dust", name = "Dust Motes", -- s6-effects-c
                      desc = "Specks of dust drift and sparkle where light falls indoors." },
                    { type = "toggle", key = "door_light", name = "Lit Doors and Windows", -- s6-effects (round 12)
                      desc = "At night, warm light spills from doorways and windows onto the ground outside." },
                } },

                { type = "header", name = "Sunlight" },
                { type = "toggle", key = "god_rays", name = "God Rays", -- s6-effects-c
                  desc = "Shafts of sunlight slant through the trees at dawn and after rain." },
                { type = "toggle", key = "indoor_windows", name = "Indoor Windows", -- s6-effects-c (round 6)
                  desc = "Indoors by day, a faint shaft of daylight falls from each window, lighting the floor with Global Illumination or Real Lights. At night daylit panes darken." },

                { type = "header", name = "Fire and Smoke" },
                { type = "toggle", key = "embers", name = "Embers and Smoke", -- s6-effects-c
                  desc = "Sparks rise from braziers, forges and torches, and a little smoke drifts with the wind." },
                { type = "group", requires = { embers }, args = {
                    { type = "toggle", key = "chimney_smoke", name = "Chimney Smoke", -- s6-effects (round 8)
                      desc = "Smoke rises from the kilns' chimneys, thinner in the rain. None indoors. Needs Embers and Smoke." },
                } },

                { type = "header", name = "In the Air" },
                { type = "toggle", key = "fireflies", name = "Fireflies", -- s6-effects-c
                  desc = "Fireflies glow by the trees on clear summer nights (the real date's season), lighting the ground with Global Illumination or Real Lights." },
                { type = "toggle", key = "birds", name = "Birds", -- s6-effects-c (round 5)
                  desc = "Flocks cross the sky in clear weather by day, their shadows on the ground below." },
                { type = "toggle", key = "heat_haze", name = "Heat Haze", -- s6-effects-c
                  desc = "The air shimmers over desert sand on sunny days and above fires." },

                { type = "header", name = "Water" },
                { type = "toggle", key = "reflections", name = "Water Reflections", -- s6-effects-c
                  desc = "Figures and trees are mirrored in water, rippling." },
                -- s6-effects-c (round 8, the owner's effects parity): Water Reflections' children, the 3D modes' water in Normal
                { type = "group", requires = { reflections }, args = {
                    { type = "toggle", key = "reflection_banks", name = "Banks and Water Depth", -- s6-effects-c (round 8)
                      desc = "A canal's bank is mirrored too, and reflections lie as deep as the water, as in the 3D view." },
                    { type = "toggle", key = "sky_in_water", name = "Sun and Moon in Water", -- s6-effects-c (round 8)
                      desc = "The sun glints and the moon shows in the water, by the hour and the moon's phase." },
                } },
            } },
        }),
    }
end
