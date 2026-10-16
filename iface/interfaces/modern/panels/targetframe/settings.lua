local C = TK.GetComponent("targetframe")

C.defaults = TK.Visibility.Defaults({
    width = 240,
    showHitBar = true,
    showPortrait = true,
    -- s6-ui-core (round 43, effects on others): the target's effects as a row of icons; the decision on questions 30-34
    -- (docs/user-related/decisions/2026-10-03-effects-on-others-defaults.md) and the report's section 5.2.
    showEffects = true,
    effectSize = 16,
    ownSize = 20,         -- round 44 (the report's section 5.2): our own casts' effects larger (WoW's own auras)
    effectTime = true,    -- the target frame's icons have room for their time
    effectsText = false,  -- the line of text as well
    creatureMode = "all",  -- the filters pick from the two name lists (Nameplates > Effect Icons' Effect Names)
    playerMode = "all",
})

C.defaultPosition = { "TOPLEFT", "TOPLEFT", 300, -20 }

C:StandardSettings("targetframe", {
    { type = "header", name = "Target" },
    { type = "toggle", key = "showHitBar", name = "Show Last Hit Bar" },
    { type = "toggle", key = "showPortrait", name = "Show Portrait" },
    { type = "range", key = "width", name = "Width", min = 160, max = 400, step = 5 },
    { type = "description", name = "Of an enemy the client knows only the name, the level and the health percentage its last hit reported." },
}, { transparency = true }) -- s6-ui-core (round 53): its own transparency (TK.PanelTransparencyArgs)

-- s6-ui-core (round 43): the Effects tab, after General Settings: the row of icons and its own filter, which picks
-- from the two name lists on Effect Icons' page (round 82: under Nameplates).
table.insert(C.tabs, 2, { name = "Effects", args = {
    { type = "toggle", key = "showEffects", name = "Show the Target's Effects" },
    -- s6-optimize (round 34): only the icon row's options depend on its switch. UpdateBuffs still shows its
    -- fallback text with icons off, and both filters below still apply to that text.
    { type = "group", requires = { TK.NeedSetting("showEffects") }, args = {
        { type = "range", key = "effectSize", name = "Icon Size", min = 12, max = 32, step = 1 },
        { type = "range", key = "ownSize", name = "Your Own Casts' Icon Size", min = 12, max = 40, step = 1 },
        { type = "toggle", key = "effectTime", name = "Show the Time under Each Icon" },
        { type = "toggle", key = "effectsText", name = "Also as a Line of Text" },
    } },
    { type = "header", name = "Creatures" },
    { type = "select", key = "creatureMode", name = "Creatures' Effects", values = TK.EffectIcons.MODES },
    { type = "header", name = "Players" },
    { type = "select", key = "playerMode", name = "Players' Effects", values = TK.EffectIcons.MODES },
    { type = "description", name = "The lists are the Buffs and Debuffs names on Nameplates > Effect Icons' Effect Names tab. The pointer over an icon says what it is (??? when not known yet), whether that is the server's word or an estimate, and how long it has left. Nothing is sent." },
} })
