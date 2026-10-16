local C = TK.GetComponent("enemyicons")

-- s6-ui-core (round 43): the defaults are the decision on questions 30-34
-- (docs/user-related/decisions/2026-10-03-effects-on-others-defaults.md), each a setting here.
-- s6-ui-core (round 82; the owner, 2026-10-09): what is drawn over others is one pane (Nameplates: its header in
-- panels/nameplates/settings.lua). This page, Effect Icons, is under it, with the icons' look and the name lists; for whom
-- they show and which, each kind's (players, creatures), are on its Players and NPCs pages (C:KindArgs), kept here.
C.defaults = {
    enabled = true,
    playerWho = "targethover",   -- question 30: the target and the one under the mouse; round 82: each kind its own
    creatureWho = "targethover",
    place = "under",      -- under the name (the owner's memory of WoW); "over": over the head
    size = 12,            -- very small, so several fit side by side
    perRow = 6,
    max = 12,
    timeText = false,     -- question 32: no time under the icons; the tooltip says it, or "time unknown"
    showUnknown = true,   -- "???" effects
    -- The owner's two name lists (head note, 2026-10-03) are the profile's effectLists since s6-input round 49
    -- (core/effecticons.lua; edited on the Effect Names tab below). Round 43's text, "A, B", saved here is still carried
    -- over by C:Migrate, then moved there as the profile loads (Modern's movedSaved, core/db.lua).
    creatureMode = "all",
    playerMode = "all",
    -- Round 44 (the owner: names put on the lists from the icons): right-clicking an icon over another figure opens its
    -- menu (Add to Buffs, Add to Debuffs); off, a right-click there reaches the map as without the icons.
    rightClick = true,
}

-- Its page goes under the Nameplates pane's (core/components.lua's SettingsNodes: parent).
C.parent = "nameplates"

-- Round 82: "Show Effects For" (who) as it was, for one kind: the target, both, or all of one kind (or of both)
local WHO = {
    target = { player = "target", creature = "target" },
    targethover = { player = "targethover", creature = "targethover" },
    creatures = { player = "off", creature = "always" },
    players = { player = "always", creature = "off" },
    everyone = { player = "always", creature = "always" },
}

--- s6-ui-core (round 45, Astra's review of round 44, P1): a saved profile's older forms, carried over before the profile
--- is checked against the defaults (DB:Normalize), which replaces a value of another type and so would empty the lists:
--- round 43's name lists as text ("Haste, #16") become the lists they name; round 43's "Show Icons For" (show: the one
--- under the mouse, or the target) becomes who (its default, all creatures, gives way to the new default); round 82's
--- one who for both kinds becomes each kind's (playerWho, creatureWho). In place; true when something changed (the
--- profile is then saved).
function C:Migrate(saved)
    local changed = false
    for _, key in ipairs({ "buffNames", "debuffNames" }) do
        if type(saved[key]) == "string" then
            saved[key] = TK.EffectIcons.Split(saved[key])
            changed = true
        end
    end
    if saved.show ~= nil then
        saved.who = ({ hover = "targethover", target = "target" })[saved.show] or saved.who
        saved.show = nil
        changed = true
    end
    if saved.who ~= nil then
        local kinds = WHO[saved.who]
        if kinds then saved.playerWho, saved.creatureWho = kinds.player, kinds.creature end
        saved.who = nil
        changed = true
    end
    return changed
end

--- s6-ui-core (round 82): a kind's rows ("player" or "creature") on the Nameplates pane's Players or NPCs page, kept in
--- this component's settings: for whom its icons show (TK.GetComponent("nameplates").WHEN) and which effects.
function C:KindArgs(kind)
    local on = TK.Needs("Effect Icons > Enabled", function() return self:DB().enabled end)
    local function row(r)
        r.get = function() return self:DB()[r.key] end
        r.set = function(node, v)
            self:DB()[r.key] = v
            self:Changed(node, r.key, v)
        end
        r.default = function() return self.defaults[r.key] end
        r.requires = { on }
        return r
    end
    return {
        { type = "header", name = "Effect Icons" },
        row({ type = "select", key = kind .. "Who", name = "Show Effects For", values = TK.GetComponent("nameplates").WHEN }),
        row({ type = "select", key = kind .. "Mode", name = "Which Effects", values = TK.EffectIcons.MODES }),
    }
end

C.tabs = {
    { name = "General Settings", args = {
        { type = "toggle", key = "enabled", name = "Enabled" },
        { type = "select", key = "place", name = "Place",
          values = { { value = "under", text = "Under the name" }, { value = "over", text = "Over the head" } } },
        { type = "range", key = "size", name = "Icon Size", min = 8, max = 32, step = 1 },
        { type = "range", key = "perRow", name = "Icons per Row", min = 1, max = 12, step = 1 },
        { type = "range", key = "max", name = "Most Icons", min = 1, max = 24, step = 1 },
        { type = "toggle", key = "timeText", name = "Show the Time under Each Icon" },
        { type = "toggle", key = "showUnknown", name = "Show Unknown Effects (???)" },
        { type = "toggle", key = "rightClick", name = "Right-Click an Icon to List Its Name" },
        { type = "description", name = "Each icon is an effect on a creature or another player; for whom they show, and which, is on the Players and NPCs pages. The pointer over it says what it is (??? when not known yet), whether that is the server's word or an estimate, and how long it has left. The server names no spell on others: names come from what the Library learned of your own spells, and the seconds left from the list the server sends as a player comes into view. Nothing is sent." },
        -- Astra's review of the report: the game's own Magic Effects option is another thing (the server's, which
        -- reports it in 08 and 23); this page never changes it, and only says what it costs.
        { type = "description", name = "The game's Magic Effects option is separate and is not changed here. With it off, the server sends fewer effects of others, so fewer icons show." },
    } },
    { name = "Effect Names", args = {
        -- s6-input (round 49, separation step 4b): the profile's effectLists (TK.EffectIcons), empty when reset
        { type = "namelist", key = "buffNames", name = "Buffs", get = function() return TK.EffectIcons.Names("buff") end,
          set = function(_, list) TK.EffectIcons.SetNames("buff", list) end, default = function() return {} end },
        { type = "namelist", key = "debuffNames", name = "Debuffs", get = function() return TK.EffectIcons.Names("debuff") end,
          set = function(_, list) TK.EffectIcons.SetNames("debuff", list) end, default = function() return {} end },
        { type = "description", name = "A name in any case (Poison), or the number an unknown effect's tooltip gives (#84). A name on a list shows as a buff or a debuff everywhere: your own effects, others', the target frame. Right-clicking one of your own effects moves its name to the other list; right-clicking an icon over another figure, or in the target frame, puts its name on a list. The Players and NPCs pages' Which Effects and the target frame's pick from these lists." },
    } },
}
