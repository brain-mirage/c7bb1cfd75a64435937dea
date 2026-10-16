-- Interface-wide settings: the global UI scale (applied by the core on start and on profile changes), the panels'
-- transparency (the shared panel style, core/widgets.lua) and reloading the Lua UI. s6-devtools (round 3): the frame-time
-- readout moved to the Debug page (components/debug).

local C = TK.GetComponent("interface")
local W = TK.UI

function C:ApplySettings()
    local db = self:DB()
    W.SetUITransparency(db.uiTransparency / 100) -- s6-ui-settings (round 4); s6-ui-core (round 53): one level
end
