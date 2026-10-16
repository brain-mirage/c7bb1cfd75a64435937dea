-- s6-modular-g (interfaces, phase 2): the Interfaces page has no frames of its own (settings.lua).
local C = TK.GetComponent("interfaces")

function C:ApplySettings() end

-- The owner's hotfix (2026-10-06): keys that switch interfaces at once, in Key Bindings, unbound by default (open question
-- 54). Next Interface cycles them in the tab's order, like the Cycle Graphics Style key ("if I bind it to 7 and im on
-- modern it goes to 7x ... press again it enables 5x ... and again enables modern"); one key per interface goes to it.
-- Each switches at once (TK.Interfaces:SwitchTo: s6-interface-5x round 13's hotfix, in place), sending nothing. The keys
-- follow the switch (byKey: bound in the profile switched to where free). INTERFACENEXT is the name
-- interface-separation.md 5.16 gives it. They act at the login screen too (atLogin: TK.Bindings:OnKey).
local function register(name, text, fn)
    TK.Bindings:RegisterCommand(name, text, fn)
    TK.Bindings.commands[name].atLogin = true
end

register("INTERFACENEXT", "Next Interface", function() TK.Interfaces:Next(true) end)
for _, interface in ipairs(TK.Interfaces:InOrder()) do
    local id = interface.id
    register("INTERFACE_" .. id:upper(), "Switch to " .. (interface.name or id), function() TK.Interfaces:SwitchTo(id, true) end)
end
