-- Key bindings for the original's other commands (plan D19, coverage-matrix.md "Key bindings"): each is a bindable
-- command that runs one action (TK.Actions), with the original's key as its default where that key is free in this
-- UI. Until the rules for them exist (plan 5.7) they are logged and nothing is sent.
--
-- The boards (the original's b, 3B 01) get a free key, Shift+B, since B opens the bag here; the micro menu has a
-- button for them.

local C = {}
TK.Commands = C

-- command, text, action kind, amount, default key, the original's key and packet (for the settings page's text).
C.list = {
    { "ATTACK", "Attack", "attack", 0, "SPACE", "Space, 13 00" },
    { "PICKUP", "Pick Up", "pickup", 0, ",", ", 07 00" },
    { "PICKUPALL", "Pick Up All", "pickup", 1, "SHIFT-,", "<, 07 01" },
    { "LOOK", "Look", "look", 0, ";", "; 09" },
    { "OPENOBJECT", "Open", "open", 0, "O", "o, 20" },
    { "RIDE", "Ride", "ride", 0, "R", "r, 1B 01 00 01" },
    { "BOARDS", "Boards", "boards", 0, "SHIFT-B", "b, 3B 01" },
    { "MAIL", "Mail", "mail", 0, "SHIFT-M", "M, 3B 09" },
    { "USERLIST", "User List", "userlist", 0, "CTRL-U", "Ctrl+w, 18" }, -- D24: Ctrl+W is Ctrl+up's
    { "REFRESH", "Refresh", "refresh", 0, "CTRL-R", "Ctrl+r, 38" },
    { "HELPMENU", "Help Menu", "helpmenu", 0, "SHIFT-F1", "Shift+F1, 43 01 FFFFFFFF" },
    { "HELPMENU2", "Help Menu 2", "helpmenu2", 0, "F2", "F2, 43 01 FFFFFFFE" },
    { "PICKUP3", "Pick Up (Ctrl)", "pickup", 3, "CTRL-,", "Ctrl+,, 07 03" },
    { "BAREHANDS", "Bare Hands", "barehands", 0, nil, "w then -, 12 00" },
    { "MINIMAPREQUEST", "Map", "minimap", 0, "M", "m, 7C" }, -- s6-world-view (round 17): the map window follows it
    -- s6-world-view (K-077): a GM's brightness keys; the original's - and = are action bar 1's keys here.
    { "BRIGHTNESSDOWN", "Brightness Down (GM)", "brightness", -1, "NUMPADMINUS", "- (GM only), nothing sent" },
    { "BRIGHTNESSUP", "Brightness Up (GM)", "brightness", 1, "NUMPADPLUS", "= (GM only), nothing sent" },
}

-- Each command's action goes with its key (the key layer "bindings"), so the key press freezes it (plan 5.9).
for _, c in ipairs(C.list) do
    local command, text, kind, amount, key = c[1], c[2], c[3], c[4], c[5]
    TK.Bindings:RegisterCommand(command, text, function() TK.Actions:RunFrozen() end, { kind = kind, amount = amount })
    if key then TK.DB.defaultBindings[key] = command end
end

-- ----- the screenshots (head note 37, plan D24) -----
--
-- Walking, Ctrl and a direction's 82, the target keys and the map's buttons are the logic's own commands
-- (TK.Bindings.builtins). In a live session the screenshot keys are 4a's fixed ones, which the logic's dispatcher takes
-- before any binding (the picture and its proof, 83); these commands take the picture offline, and on any other key
-- they are bound to (no proof: the original's key was not pressed).
C.screenshots = {
    { "SCREENSHOT", "Screenshot (PNG)", "SCROLLLOCK", "CTRL-SHIFT-4" },
    { "SCREENSHOTBMP", "Screenshot (BMP)", "SHIFT-SCROLLLOCK", "CTRL-SHIFT-3" },
}

for _, c in ipairs(C.screenshots) do
    TK.Bindings:RegisterCommand(c[1], c[2], function() end)
    for i = 3, #c do TK.DB.defaultBindings[c[i]] = c[1] end
end
