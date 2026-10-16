local C = TK.GetComponent("partyframes")
local V = require("interfaces.modern.vitals") -- s6-ui-core (round 82): the number forms

C.MAX = 10

C.defaults = TK.Visibility.Defaults({
    maxShown = 8,
    growth = "DOWN",
    spacing = 6,
    width = 200,
    showNumbers = false,
    numberFormat = "value", -- s6-ui-core (round 82): the player frame's forms; current / max, as before
    showPlayer = false,
})

-- Under the player frame.
C.defaultPosition = { "TOPLEFT", "TOPLEFT", 20, -112 }

C:StandardSettings("partyframes", {
    { type = "header", name = "Party" },
    { type = "range", key = "maxShown", name = "Members Shown", min = 1, max = C.MAX, step = 1 },
    { type = "toggle", key = "showPlayer", name = "Show the Player" },
    { type = "select", key = "growth", name = "Growth Direction",
      values = { { value = "DOWN", text = "Down" }, { value = "UP", text = "Up" },
                 { value = "RIGHT", text = "Right" }, { value = "LEFT", text = "Left" } } },
    { type = "range", key = "spacing", name = "Spacing", min = 0, max = 30, step = 1 },
    { type = "range", key = "width", name = "Width", min = 140, max = 320, step = 5 },
    { type = "toggle", key = "showNumbers", name = "Show Numbers" },
    { type = "select", key = "numberFormat", name = "Number Format", values = V.FORMATS,
      requires = { TK.Needs("Show Numbers", function(db) return db.showNumbers end) },
      desc = "Numbers too wide for one line are drawn as two rows over the bar." },
}, { transparency = true }) -- s6-ui-core (round 53): its own transparency (TK.PanelTransparencyArgs)
