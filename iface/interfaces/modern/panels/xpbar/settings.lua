local C = TK.GetComponent("xpbar")

C.defaults = TK.Visibility.Defaults({
    width = 454,
    height = 8,
    showText = "hover",
})

C.defaultPosition = { "BOTTOM", "BOTTOM", 0, 5 }

C:StandardSettings("xpbar", {
    { type = "header", name = "Bar" },
    { type = "range", key = "width", name = "Width", min = 100, max = 1600, step = 2 },
    { type = "range", key = "height", name = "Height", min = 4, max = 30, step = 1 },
    { type = "select", key = "showText", name = "Text",
      values = { { value = "never", text = "Never" }, { value = "hover", text = "On mouse-over" },
                 { value = "always", text = "Always" } } },
}, { sub = 13 }) -- s6-ui-settings: its own panel, a top-level row of the Interface tab (the owner)
