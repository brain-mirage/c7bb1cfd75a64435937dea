local C = TK.GetComponent("tooltips")

C.defaults = {
    anchor = "beside",
    -- on in Modern; s6-ui-core (round 61): 7.x and 5.x turn it off (their manifests' migrate, worldTooltipsOff: the
    -- original names nothing hovered in the world)
    world = true,
}

C.tabs = { { name = "Tooltips", args = {
    { type = "description", name = "Tooltips show what the client knows of what is under the mouse, the learned names and "
        .. "mana costs included; nothing is asked of the server for them." },
    { type = "select", key = "anchor", name = "Position",
      values = { { value = "beside", text = "Beside what is hovered" }, { value = "cursor", text = "At the mouse" },
                 { value = "corner", text = "Bottom right corner" } } },
    -- s6-ui-core (round 65): this label exceeds a half-row and was clipped by the page's right edge.
    -- Use the settings window's existing full-row layout; the preference and world hover behavior stay the same.
    { type = "toggle", key = "world", name = "Players, Creatures and Items in the World", width = "full" },
} } }
