-- s6-interp: applies the profile's Animation Interpolation to the object layers, on start, on each change and on a profile
-- switch. Drawing only: nothing here reaches the wire.

local C = TK.GetComponent("interpolation")

function C:ApplySettings()
    local db = self:DB()
    -- s6-ui-core (round 54): on only while Graphics > Advanced's Enable Advanced Graphics is on too; s6-optimize (round
    -- 33): as its row's need says (Component:Applied), followed at once when that switch changes
    local on = self:Applied("enabled", db) == true
    CS.TK.Objects.AnimationInterpolation.Set(on, db.method or "balanced", math.floor(tonumber(db.frames) or 2))
end
