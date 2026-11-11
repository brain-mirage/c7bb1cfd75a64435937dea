-- s6-modular-g (interfaces, phase 2; docs/development/interfaces.md, "The menu button"): a small button at
-- the bottom right in every interface, so the game menu is always one click away whatever an interface's keys took (7.x's
-- Escape is the original's). Its page has its Layout tab, and edit mode moves it.
-- s6-ui-core (round 60; the owner, 2026-10-06: "it should be under All interfaces in ui as a subpage Menu. Although by
-- default it should be turned off whiler in modern. and on it 5x and 7x"): no longer always on (the owner's earlier
-- answer, open question 17): a shared panel (interfaces/modern/interface.lua), so its page Menu is the Interface tab's
-- under All interfaces (under Panes since round 83, the owner's request of 2026-10-09), with its Enabled switch. Off by
-- default, as Modern's first profile has it; 7.x's and 5.x's first profiles turn it on as every interface's shared panel
-- (TK.Interfaces:ApplyDefaults), and their profiles made before once (their manifests' migrate, "menuButtonOn"). The
-- player's own choice is kept after that. It sends nothing.

local C = TK.GetComponent("menubutton")

C.defaults = TK.Visibility.Defaults({ enabled = false })
C.defaultPosition = { "BOTTOMRIGHT", "BOTTOMRIGHT", -2, 2 }

C.tabs = {
    { name = "General Settings", args = {
        { type = "toggle", key = "enabled", name = "Enabled" },
    } },
    { name = "Layout", args = TK.LayoutArgs(function() return "menubutton" end) },
}
