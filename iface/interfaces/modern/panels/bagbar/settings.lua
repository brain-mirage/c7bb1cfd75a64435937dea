local C = TK.GetComponent("bagbar")

C.defaults = TK.Visibility.Defaults({
    showFree = true,
})

C.defaultPosition = { "BOTTOMRIGHT", "BOTTOMRIGHT", -20, 62 }

C:StandardSettings("bagbar", {
    { type = "header", name = "Bag" },
    { type = "toggle", key = "showFree", name = "Show Free Slots" },
}, { sub = 11 }) -- s6-ui-settings: its own panel, a top-level row of the Interface tab (not one of the Bars)
