-- s6-modular-b (round 14): applies the profile's 3D Character Test to the drawing host, on start (on at start draws 3D at
-- once), on each change and on a profile switch. The Characters choice is the Graphics Styles page's, and stays as it is.
-- s6-reprojection (round 29; the head's note, QA's next43): 3D Map Objects is the Graphics Styles page's Map Objects choice
-- "3D" now, where it was a toggle on this page; a profile that had the toggle on gets that choice, once.

local C = TK.GetComponent("character3dtest")

function C:ApplySettings()
    CS.TK.Modular.Draw.Characters3d.SetTesting(self:DB().testing == true)
    local db = self:DB()
    if db.mapObjects ~= nil then -- s6-reprojection (round 29): the old toggle, carried over once
        if db.mapObjects == true then
            local styles = TK.GetComponent("graphicsstyles")
            local chosen = styles:DB()
            -- the style the toggle drew the objects without a model in stays theirs (Astra's P2 on round 29's pass 3)
            if chosen["map-objects"] ~= "3d-objects" then chosen["option:3d-objects:others"] = chosen["map-objects"] end
            chosen["map-objects"] = "3d-objects"
            styles:ApplySettings()
        end
        db.mapObjects = nil
        TK.DB:MarkDirty()
    end
end
