local C = TK.GetComponent("bag")

-- The original's inventory starts as a compact list (NewInventoryPane's constructor); ours starts as the full grid.
-- s6-interface-5x (round 12, separation step 1): enabled is the bag window's switch (Modern's Bag panel; off in 7.x's
-- and 5.x's first profiles since build 46), as the other windows' (interfaces/modern/panels/windows).
C.defaults = {
    enabled = true,
    view = "grid",
    expanded = true,
}

C.tabs = { { name = "General Settings", args = { -- the switch on its General Settings tab, as every panel's
    { type = "toggle", key = "enabled", name = "Enabled" },
    { type = "description", name = "Turned off, the bag's keys and buttons show the items only where another panel "
        .. "draws them." },
    { type = "description", name = "The bag window's List, Grid and Expand buttons change these too. The mouse wheel "
        .. "scrolls a view that has more than it shows." },
    { type = "select", key = "view", name = "View",
      values = { { value = "grid", text = "Grid: the items' icons" },
                 { value = "list", text = "List: a row per item, with its name" } } },
    { type = "toggle", key = "expanded", name = "Show Every Slot (expanded)" },
    { type = "description", name = "Expanded shows all 52 lettered slots, the empty ones too; otherwise only the slots "
        .. "that hold an item." },
} } }
