-- s6-effects (round 1): applies the profile's Advanced Weather and Advanced Lighting settings to the world view
-- (TK.WorldView.AdvancedEffects), on start, on each change and on a profile switch; the world view takes them at its next
-- frame. Nothing is sent: these are drawing settings of our own, and the original's Weather option (1B 01 06) is never
-- touched (the server would then stop sending the weather the effects follow).
-- s6-optimize (round 33; the owner, 2026-10-06: a checked sub-setting whose feature is off "should remain enabled but
-- greyed out ... and NOT be applied"): each switch goes as the game takes it, every need of its row met
-- (Component:Applied: under its page's master, its parent on, Global Illumination and Real Lights with the World View's
-- Shadows), so the world view reads each one alone and its pages' needs are written once, in settings.lua. A volume,
-- the transition and the sway's speed go as stored: they count only while their effect is on.

local C = TK.GetComponent("advancedeffects")

function C:ApplySettings()
    local db = self:DB()
    local function on(key) return self:Applied(key, db) == true end
    CS.TK.WorldView.AdvancedEffects.Set(on("weather"), tonumber(db.transition) or C.defaults.transition, on("wind"),
        on("lighting"), tonumber(db.wind_sound) or C.defaults.wind_sound)
    -- s6-effects (round 11): the Wind Shader's Sway Speed, tiles a second in the lightest wind and in the strongest
    local speed = type(db.wind_speed) == "table" and db.wind_speed or C.defaults.wind_speed
    CS.TK.WorldView.AdvancedEffects.SetSwaySpeeds(tonumber(speed[1]) or C.defaults.wind_speed[1],
        tonumber(speed[2]) or C.defaults.wind_speed[2])
    -- s6-effects-c: Advanced Lighting's switches under its master
    CS.TK.WorldView.AdvancedEffects.SetLighting(on("sky_light"), on("real_lights"), on("sun_shadows"))
    CS.TK.WorldView.AdvancedEffects.SetLightingExtras(on("embers"), on("fireflies"), on("bloom"), -- s6-effects-c
        on("dust"), on("god_rays"), on("silhouettes"), on("reflections"), -- s6-effects-c (rounds 3-4): the extras
        on("heat_haze"), on("colour_by_hour"), on("birds"), -- s6-effects-c (rounds 4-5)
        on("indoor_windows")) -- s6-effects-c (round 6)
    CS.TK.WorldView.AdvancedEffects.SetChimneySmoke(on("chimney_smoke")) -- s6-effects (round 8): Embers and Smoke's child
    -- s6-effects-c (round 8, the owner's effects parity): the children of Sun Shadows and of Water Reflections
    CS.TK.WorldView.AdvancedEffects.SetLightingParity(on("moon_shadows"), on("height_shading"),
        on("reflection_banks"), on("sky_in_water"))
    CS.TK.WorldView.AdvancedEffects.SetPrecipitation(on("rain"), on("snow"), -- s6-effects-b
        tonumber(db.rain_sound) or C.defaults.rain_sound) -- s6-effects-b
    CS.TK.WorldView.AdvancedEffects.SetExtras(on("snow_cover"), on("footprints"), on("leaves")) -- s6-effects-b
    -- s6-effects (round 2): the lightning (on unless off: a profile always has it, its default) and its thunder
    CS.TK.WorldView.AdvancedEffects.SetLightning(self:Applied("lightning", db) ~= false,
        tonumber(db.thunder_sound) or C.defaults.thunder_sound)
    -- s6-effects (round 12): the storm outside heard and seen indoors, and the buildings' light outside at night
    CS.TK.WorldView.AdvancedEffects.SetIndoors(on("indoor_lightning"), on("roof_rain"))
    CS.TK.WorldView.AdvancedEffects.SetDoorLight(on("door_light"))
    -- s6-effects (rounds 3-4): Advanced Weather's own extras: the mist, the wet ground's gloss and puddle reflections
    CS.TK.WorldView.AdvancedEffects.SetWeatherExtras(on("fog"), on("wet_gloss"), on("puddle_reflections"),
        on("rain_ripples")) -- s6-effects (round 6): the rain's ripples
end
