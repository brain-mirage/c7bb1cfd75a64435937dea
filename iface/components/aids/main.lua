-- s6-reprojection-cloud-3 (run 21; the owner, head note 67): the Aids tab's switches (settings.lua) handed to C#'s
-- WorldAids, which the world view reads where it draws (TK.WorldView.DebugLayer). Drawing only: nothing here sends
-- anything.

local C = TK.GetComponent("aids")
local H = __tk

function C:ApplySettings()
    local db = self:DB()
    H:SetMapAid("edges", db.unwalkableEdges == true)
    H:SetMapAid("warps", db.warpPoints == true)
end
