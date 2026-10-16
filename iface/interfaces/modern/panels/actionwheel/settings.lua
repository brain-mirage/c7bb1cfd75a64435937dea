local C = TK.GetComponent("actionwheel")

C.defaults = {
    enabled = true, -- s6-interface-5x (round 12, build 46): its switch (Modern's interface.lua)
    mode = "hold",
    stayOpen = false,
    releasePicks = false,
    markNoMana = true, -- s6-ui-core (round 83): the red edges, as the action bars' (interfaces/modern/slotmark.lua)
    markAether = true,
}

-- s6-interface-5x (round 12, build 46): "General Settings", the tab every panel's switch is on (InterfacesPlayTests)
C.tabs = { { name = "General Settings", args = {
    { type = "toggle", key = "enabled", name = "Enabled" },
    { type = "description", name = "A key opens a wheel of actions around the mouse; moving over a segment highlights it, "
        .. "and a click on it runs its action. A click outside the wheel, or Escape, closes it." },
    { type = "select", key = "mode", name = "Mode",
      values = { { value = "hold", text = "Hold: shown while the key is held" },
                 { value = "toggle", text = "Toggle: a press opens it, a pick or the key closes it" } } },
    -- s6-optimize (round 34): these options only take effect in hold mode (main.lua's click/release paths).
    -- Their saved values stay as chosen while toggle mode is in use.
    { type = "group", requires = { TK.NeedSetting("mode", "hold") }, args = {
        { type = "toggle", key = "stayOpen", name = "Stay Open After a Pick" },
        { type = "toggle", key = "releasePicks", name = "The Key's Release Picks (hold mode)" },
        { type = "description", name = "In hold mode a click picks; with the release picking, letting go of the key runs the "
            .. "segment under the mouse (none when the mouse is over no segment), as that release's input." },
    } },
    { type = "header", name = "Keys" },
    { type = "binding", name = "Action Wheel", command = "ACTIONWHEEL" },
    { type = "binding", name = "Action Wheel (multi-pick)", command = "ACTIONWHEEL_MULTI" },
    { type = "description", name = "Multi-pick opens the wheel while its key is held: each click runs its segment, and the "
        .. "release closes it without a pick." },
    { type = "header", name = "Segments" },
    { type = "description", name = "Drag spells and items onto the wheel's segments, as onto a hotbar button." },
    -- s6-interface-5x (round 13, step 11): only while the wheel is loaded (on)
    { type = "execute", name = "Show the Wheel", func = function() if C:Loaded() then C:Open("edit") end end },
} } }
-- s6-ui-core (round 83; the owner, 2026-10-09: the red edge "on spells, not only the bars")
require("interfaces.modern.slotmark").Args(C.tabs[1].args)
