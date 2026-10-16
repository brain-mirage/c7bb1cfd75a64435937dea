-- s6-interp (the owner, 2026-10-03): "can quickly add in an interpolator for animations like mobs and spells, add a few
-- interpolation methods, IE the best mode? Is that an optical version? and an in-between with a good trade-off and a quick
-- one. Also have an input box default to 2 for doubling. You can just click to enable it, this is a test setting."
-- The Experimental tab's Animation Interpolation page: the switch (off by default), the method and the frames, saved in
-- the profile like every other setting; main.lua applies them (TK.Objects.AnimationInterpolation). At the login screen
-- and in the game, so it can be switched while watching the creatures.
-- s6-ui-core (round 54; the owner, 2026-10-05: "The interpolation settings in Experimental should be moved there"): it is
-- Graphics > Advanced > Interpolation now (core/settings.lua's S.places sets where it is listed), needs Enable Advanced
-- Graphics there (its (!)), and its explanation is in tooltips (the owner's short-text rule).
-- s6-ui-core (round 60; the owner, 2026-10-06: "Change the interpolation page on settings to be called Motion. Move the
-- smooth character movement setting from experimental misc here."): the page is Motion, by type: Movement (the world
-- view's Smooth Character Movement, its row components/worldview/settings.lua's) and Animation (this component's
-- switch, its Method and Frames under it). The keys are as they were.

local C = TK.GetComponent("interpolation")

C.defaults = { enabled = false, method = "balanced", frames = 2 }

local METHODS = {
    { value = "quick", text = "Quick (cross-fade)" },
    { value = "balanced", text = "Balanced (motion-matched blend)" },
    { value = "best", text = "Best (optical flow)" },
}

-- s6-ui-core (round 54): what its rows need to have an effect, their (!) (core/settings.lua); round 60: the switch's by
-- its key (TK.NeedSetting, named by its row)
local advanced = TK.Needs("Advanced > Enable Advanced Graphics", function() return TK.Machine:AdvancedGraphics() end)
local interpolating = TK.NeedSetting("enabled")

-- s6-ui-core (round 62; the owner, the head's note inbetween-cache: "add a button to clear that cache and also have it say
-- how much space its taking up?"): the in-between cache on disk, read as the page shows (a description by function is
-- read again on each refresh, so after Clear Cache too)
local function cacheLine()
    local AI = CS.TK.Objects.AnimationInterpolation
    local n, bytes = AI.CachedPictures(), AI.CachedBytes()
    -- under a megabyte in kilobytes (the live check: a few small pictures read "0.0 MB")
    local size = bytes < 1048576 and string.format("%d KB", math.ceil(bytes / 1024))
        or string.format("%.1f MB", bytes / 1048576)
    return string.format("Cache: %s, %s %s", size, TK.Util.FormatNumber(n), n == 1 and "picture" or "pictures")
end

function C:SettingsNodes()
    return { {
        id = "interpolation", title = "Motion", order = self.order, category = "experimental", -- placed by S.places
        -- s6-interp round 2: s6-audio's Sound page has this page's order (916) too, and the list's sort is not stable, so
        -- sub places this one after it (the order the settings tests list)
        sub = 1,
        atLogin = true,
        db = function() return self:DB() end,
        defaults = function() return self.defaults end,
        tabs = { { name = "Motion", args = {
            { type = "header", name = "Movement" }, -- s6-ui-core (round 60)
            TK.GetComponent("worldview").smoothMovementOption,
            TK.GetComponent("worldview").fix2dFlickerOption, -- s6-world-view (round 39): its Fix 2D Flicker, a step in under it
            { type = "header", name = "Animation" }, -- s6-ui-core (round 60)
            { type = "toggle", key = "enabled", name = "Animation Interpolation", requires = { advanced },
              desc = "Pictures drawn between the creatures' and spell effects' frames. Characters are not changed." },
            { type = "group", requires = { advanced, interpolating }, args = { -- s6-ui-core (round 60): the switch's own
                { type = "select", key = "method", name = "Method", values = METHODS,
                  desc = "Quick cross-fades; Balanced blends the motion; Best follows each pixel (made in the background)." },
                { type = "input", name = "Frames", live = true,
                  desc = "How many pictures each frame becomes: 2 doubles them, up to 16.",
                  get = function() return tostring(self:DB().frames or 2) end,
                  set = function(_, text)
                      local n = tonumber(text)
                      if n and n == math.floor(n) and n >= 2 and n <= 16 then
                          self:DB().frames = n
                          self:ApplySettings()
                      end
                  end,
                  default = "2" },
            } },
            -- s6-ui-core (round 62): the cache's line and its button (TK.Objects.AnimationInterpolation's); not under the
            -- switch: a cache made before may be cleared with it off
            { type = "description", name = cacheLine, id = "cache",
              desc = "In-between pictures kept on disk, so each is made only once." },
            { type = "execute", name = "Clear Cache", func = function() CS.TK.Objects.AnimationInterpolation.ClearCache() end,
              desc = "Deletes the kept pictures, on disk and in memory. They are made again as needed." },
        } } },
    } }
end
