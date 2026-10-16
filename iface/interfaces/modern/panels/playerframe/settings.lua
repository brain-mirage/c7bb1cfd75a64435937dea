local C = TK.GetComponent("playerframe")
local V = require("interfaces.modern.vitals") -- s6-ui-core (round 82): the number forms

C.defaults = TK.Visibility.Defaults({
    width = 260,
    showNumbers = false,
    numberFormat = "both",
    damageTaken = false,   -- s6-ui-core (round 82; the owner, 2026-10-09): the damage taken, a switch
    showXP = true,
    showPortrait = true,
    useProfileImage = false,   -- s6-characters seam (the owner, 2026-10-01): the portrait's profile image
})

C.defaultPosition = { "TOPLEFT", "TOPLEFT", 20, -20 }

-- s6-ui-core (round 54): what it needs to have an effect, its (!) (TK.Needs: was disabled)
local numbers = TK.Needs("Show Numbers", function(db) return db.showNumbers end)

C:StandardSettings("playerframe", {
    { type = "header", name = "Bars" },
    { type = "toggle", key = "showNumbers", name = "Show Numbers" },
    -- s6-ui-core (round 82; the owner): current, current / max, the percentage, or current or current / max with it;
    -- two rows over the bar when one line does not fit
    { type = "select", key = "numberFormat", name = "Number Format", requires = { numbers }, values = V.FORMATS,
      desc = "Health and mana can reach the millions: numbers too wide for one line are drawn as two rows over the bar." },
    { type = "toggle", key = "damageTaken", name = "Show Damage Taken",
      desc = "The health or mana just lost turns red, then shrinks away." },
    { type = "toggle", key = "showXP", name = "Show XP Bar" },
    { type = "toggle", key = "showPortrait", name = "Show Portrait" },
    -- s6-characters seam (the owner, 2026-10-01): the character's profile image (its .jpf) in place of its figure.
    { type = "toggle", key = "useProfileImage", name = "Use my profile image as my portrait",
      requires = { TK.Needs("Show Portrait", function(db) return db.showPortrait end) } }, -- s6-ui-core (round 54)
    { type = "range", key = "width", name = "Width", min = 180, max = 420, step = 5 },
}, { transparency = true }) -- s6-ui-core (round 53): its own transparency (TK.PanelTransparencyArgs)
