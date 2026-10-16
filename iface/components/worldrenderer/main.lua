-- s6-modular (round 13; the owner, 2026-10-03): the world renderers' keys and the settings window's refresh. The choice and
-- the renderers themselves are C# (TK.Modular.Draw.WorldRenderers); nothing here sends anything.

local C = TK.GetComponent("worldrenderer")
local R = CS.TK.Modular.Draw.WorldRenderers

-- The settings window shows the page again one frame after a change (a choice, a renderer that failed): the Experimental
-- tab's options are the chosen renderer's.
local pending = CreateFrame("Frame", "TKWorldRendererRefresh", UIParent)
pending:SetSize(1, 1)

function C:RefreshSettings()
    pending:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        local S = TK.Settings
        if S.selected and S:FindNode(S.selected.id) then S:Select(S.selected.id) end
    end)
end

TK.On("TK_WORLD_RENDERER_CHANGED", function() C:RefreshSettings() end)

-- The bindable switch: the next of Normal and the installed renderers' modes, at the login screen or in the game
-- (s6-ui-core, build 41: no Allow Switching During Gameplay any more). No default key.
TK.Bindings:RegisterCommand("WORLDRENDERERNEXT", "Next World Renderer", function() R.Next() end)

-- Each installed renderer's own actions (their manifests), to that renderer while it draws. s6-reprojection (round 3):
-- an action's suggested key is its default only where no other default binding has that key.
for line in string.gmatch(R.Actions(), "[^\n]+") do
    local module, id, name, key = string.match(line, "^([^|]*)|([^|]*)|([^|]*)|(.*)$")
    if module then
        local command = "WORLDRENDERER " .. module .. " " .. id
        TK.Bindings:RegisterCommand(command, name, function() R.Action(module, id) end)
        if key ~= "" and TK.DB.defaultBindings[key] == nil then TK.DB.defaultBindings[key] = command end
    end
end
