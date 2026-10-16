local C = TK.GetComponent("gameoptions")

C.defaults = {}
C.category = "general" -- the original's game options: the settings list's General tab

-- s6-ui-settings: a local switch on the page, kept in settings.toml [options] (this computer's, not the profile's) and
-- applied in the game at once. invert shows the switch turned over (Simple Click is double_click off).
local function switch(key, name, invert)
    return { type = "toggle", name = name, machine = true,
        get = function() return TK.Game.Options.Get(key) ~= (invert == true) end,
        set = function(_, on) TK.Game.Options.Set(key, on ~= (invert == true)) end,
        default = function() return __tk:ClientSettingDefaultBool("options", key) ~= (invert == true) end }
end

C.tabs = {
    { name = "General Settings", args = {
        { type = "description", name = "The original's options tab: the options the server keeps for your character, and this computer's own. Each server option turns over on the server, exactly as the original's row did, and shows the server's answer. Open it in the game with F10 (Key Bindings: Game Options)." },
        { type = "execute", name = "Open Game Options", func = function() TK.Game.Options.Toggle() end },
        { type = "header", name = "This Computer's Switches" },
        switch("double_click", "Simple Click (one click acts in the target panes)", true),
        switch("click_look", "Right Click Look (Shift+R)"),
        switch("tab_v_swap", "Tab / V Swap (Shift+F11)"),
        switch("orb_target_share", "Orb / Spell Target Share"),
        switch("click_move", "Click to Move (Shift+F12)"),
        -- s6-ui-core (round 82; the owner, 2026-10-09): Show Damage moved to Modern's Nameplates page (the description below)
        switch("balloon", "Chat Balloon Fill"),
        -- m_hearSnoreMode (0-2; the row shows any but 0 as on, and turns it to 1 or 0).
        { type = "toggle", name = "Listen to Snore", machine = true,
            get = function() return __tk:ClientSettingInt("options", "hear_snore") ~= 0 end,
            set = function(_, on) TK.Game.Options.Keep("page", "hear_snore", on and 1 or 0); __tk:ApplyOptions() end,
            default = function() return __tk:ClientSettingDefaultInt("options", "hear_snore") ~= 0 end },
        switch("f1_swap", "F1 / Shift+F1 Swap (the Help Menu on F1)"),
        { type = "description", name = "Map Effects, Shadows, See-Through and Object Transparency are on General > Graphics > World View; Low, High and Manual are in the Game Options window. Show Damage, the floating damage and healing numbers, is on Modern's Nameplates page, and in the game Shift+F10 and the Game Options window's row." },
    } },
}
