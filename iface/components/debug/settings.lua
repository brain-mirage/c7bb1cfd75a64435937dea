local C = TK.GetComponent("debug")

-- s6-devtools (round 3; the owner, 2026-10-05: "add a debug panel to the settings menu at the bottom"; the head's note:
-- "have all of that added"): the Debug page, the last entry of the settings window (the Experimental tab's, after the core
-- pages: core/settings.lua's `last`), in the game and at the login screen. Every switch is off by default (s6-effects round
-- 40: but the Weather & Lighting tab's Transitions, below, as the owner asked). Show Frame Time
-- moved here from Interface's Diagnostics (the owner: "If we have those settings elsewhere please move them here"; main.lua
-- carries a profile's choice over). Detached Camera is never kept: it is off at every start. Drawing and reading only:
-- nothing on this page sends anything.
C.atLogin = true
C.category = "experimental"

C.defaults = {
    showFrameTime = false,
    showFrameGraph = false,
    showCounters = false,
    showMapInfo = false,
    grid = false,
    coordinates = false,
    inspector = false,
    blocked = false,
    warps = false,
    lights = false,
    windows = false,
}

C.tabs = {
    { name = "Debug", args = {
        { type = "header", name = "Performance" },
        { type = "toggle", key = "showFrameTime", name = "Show Frame Time" },
        { type = "toggle", key = "showFrameGraph", name = "Show Frame-Time Graph" },
        { type = "toggle", key = "showCounters", name = "Show Performance Counters",
          desc = "Memory, collections, draw calls and the map's sprites." },
        { type = "header", name = "World" },
        { type = "toggle", key = "showMapInfo", name = "Show Map Info", desc = "The map's number, name, size and indoor flag, and your cell." },
        { type = "execute", name = "Reload World Hints", func = function() C:ReloadWorldHints() end,
          desc = "Reads edited local hint files again and redraws the world. Bind a key on the Key Bindings page." },
        { type = "toggle", key = "grid", name = "Show Tile Grid" },
        { type = "toggle", key = "coordinates", name = "Show Tile Coordinates" },
        { type = "toggle", key = "inspector", name = "Tile Inspector",
          desc = "The tile under the mouse: its tile and object, the packs they come from, and their hints." },
        { type = "toggle", key = "blocked", name = "Show Blocked Cells" },
        { type = "toggle", key = "warps", name = "Show Warps", desc = "The exits the Library knows on this map." },
        { type = "toggle", key = "lights", name = "Show Light Sources" },
        { type = "toggle", key = "windows", name = "Show Window Hints" },
        { type = "header", name = "Camera" },
        { type = "toggle", name = "Detached Camera", default = false,
          get = function() return __tk:IsDetachedCamera() end,
          set = function(_, on) C:SetDetached(on) end,
          disabled = function() return not TK.GameState:InWorld() end,
          desc = "Moves the view, not you: movement keys pan, Q and E turn, R and F tilt, Z and X zoom (3D). Other keys do nothing. Escape ends it." },
    } },
}

-- s6-effects (round 40; the owner, 2026-10-08: "It should override the clients weather system IE it makes the client
-- ignore the server and play whatever you want. Make it a subtab under debug so can test everything. You can change the
-- time of day, the weather, start other effects trigger lighting etc and you can reset it all back to server etc.
-- Transitions are still enabled but you can click it off etc."): the Weather & Lighting tab. With Override on, every view
-- draws (and the weather's sounds follow) the hour, the weather and the effects chosen here in place of the server's; the
-- rows under it are greyed and not applied while it is off, and the buttons act only with it on. Each effect still shows
-- only with its own switch on the Weather and Lighting pages. Drawing and sound only: the client receives and answers the
-- server's weather, hour and map packets exactly as before (C#'s TK.WorldView.WeatherOverride, the wire's note there), and
-- nothing on this tab sends anything. main.lua applies it.
C.defaults.wxOverride, C.defaults.wxHour, C.defaults.wxWeather, C.defaults.wxTransitions = false, 12, 0, true
C.defaults.wxClouds, C.defaults.wxMist, C.defaults.wxWind = -1, -1, -1 -- -1: as the clock has it (WeatherOverride.Natural)

local override = TK.NeedSetting("wxOverride")
local overrideOn = TK.NeedSetting("wxOverride", true, "disable")
local CLOCK = "As the clock has it"
-- the rows that need Advanced Weather too, given its need when every settings file is loaded (C:SettingsNodes)
local advancedRows = {}
local function advanced(row) advancedRows[#advancedRows + 1] = row return row end

C.tabs[#C.tabs + 1] = { name = "Weather & Lighting", args = {
    { type = "toggle", key = "wxOverride", name = "Override the Server's Weather and Time",
      desc = "Draws the hour and the weather chosen below in every view instead of the server's. The server's own go on arriving and are answered as before; nothing is sent. Reset to Server, or this switch off, shows the server's again." },
    { type = "range", key = "wxHour", name = "Time of Day (hours)", min = 0, max = 23.75, step = 0.25, requires = { override },
      desc = "Held still: the sun, the moon and the night as the original draws them at that hour on this map." },
    { type = "select", key = "wxWeather", name = "Weather", requires = { override },
      values = { { value = 0, text = "Clear" }, { value = 1, text = "Rain" }, { value = 2, text = "Snow" } } },
    advanced({ type = "select", key = "wxClouds", name = "Clouds",
      values = { { value = -1, text = CLOCK }, { value = 0, text = "Clear sky" }, { value = 1, text = "Light clouds" },
                 { value = 2, text = "Patchy (most of the sky)" }, { value = 3, text = "Big banks" } },
      desc = "The dry sky's clouds; rain and snow bring their overcast over them." }),
    advanced({ type = "select", key = "wxMist", name = "Fog and Mist",
      values = { { value = -1, text = CLOCK }, { value = 0, text = "None" }, { value = 40, text = "Light" }, { value = 100, text = "Thick" } } }),
    advanced({ type = "select", key = "wxWind", name = "Wind",
      values = { { value = -1, text = CLOCK }, { value = 0, text = "Still" }, { value = 20, text = "Light air" },
                 { value = 45, text = "Breeze" }, { value = 70, text = "Strong" }, { value = 100, text = "Gale" } },
      desc = "The wind's base; its gusts come on it by the clock." }),
    { type = "toggle", key = "wxTransitions", name = "Transitions", requires = { override },
      desc = "On: a change of weather comes in over the Weather page's Transition, as the server's does. Off: at once." },
    advanced({ type = "execute", name = "Lightning Strike", func = function() C:WeatherStrike(true) end,
      desc = "A strike now: its flash, light and thunder (with the Weather page's Lightning on)." }),
    advanced({ type = "execute", name = "Thunder", func = function() C:WeatherStrike(false) end,
      desc = "A strike's thunder alone, farther off." }),
    advanced({ type = "execute", name = "Weather Front", func = function() C:WeatherFront() end,
      desc = "Turns the weather between clear and rain over a Transition (the clouds roll in first), even with Transitions off." }),
    { type = "execute", name = "Reset to Server", func = function() C:ResetWeather() end,
      desc = "Every row of this tab back to its default and Override off: the server's weather and hour again." },
} }

--- The page's node, marked last: it ends the settings window's list (core/settings.lua).
function C:SettingsNodes()
    -- round 40: the Weather & Lighting tab's needs, the Weather page's master switch made by advancedeffects' settings.lua
    local effects = TK.GetComponent("advancedeffects")
    for _, row in ipairs(advancedRows) do
        row.requires = { row.type == "execute" and overrideOn or override, effects and effects.weatherNeed or nil }
    end
    return { {
        id = self.name, title = self.title, order = self.order, tabs = self.tabs, atLogin = true, category = "experimental",
        last = true,
        db = function() return self:DB() end,
        defaults = function() return self.defaults end,
    } }
end
