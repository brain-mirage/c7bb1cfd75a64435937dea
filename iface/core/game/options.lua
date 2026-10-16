-- s6-play-modes (round 8; docs/development/interface-separation.md, step 4 and section 5.8): the game layer's Game Options,
-- the original's options tab (NewOptionPane, side panel tab 6) as every interface's options use it: the local switches
-- (settings.toml [options], Config's registry values), the server's options as the session keeps them, a row's press and
-- its offline part, the original's option keys, the F1 swap, Display names (N) and the opener (F10). Moved from the Game
-- Options component (components/gameoptions/main.lua), which keeps its settings page (Modern's window is in Modern's
-- folder since step 7: interfaces/modern/panels/windows/gameoptions.lua, s6-modular-g round 17).
--
-- The tab's rows, by the original's row number (NewOptionPane::HandlePointerOrMouseEvent 0x00540910, ui/OptionPane.cpp:986):
--
--   Magic 3, Weather 4, Advice 10                           1B 01 05 / 06 / 04 (three bytes, 0x00540E50); Magic: Manual
--   Fixed Movement 7, Hear Shouts 11, Hear Whispers 12      1B 01 07 / 03 / 01 00 (UserPane's sender 0x005A8C60)
--   Sound Effects 17                                        1B 01 63 0D v, v the server's state turned over
--   Map 2, Shadow 18, Chat (balloon fill) 19                local, and the radio to Manual
--   Simple Click 14, Orb / Spell Target Share 23            local (Simple Click is double-click turned over)
--   Snore 13                                                local: the snore mode, 1 or 0, and its line (motion 16's
--                                                           sound, 305, plays only at 1)
--   F1 / Shift+F1 Swap 24                                   local: moves the Help Menu (43 01) to F1 and back
--   Low 20, High 21, Manual 22                              the radio; Low and High set the map effects, the shadows and
--                                                           the balloon fill to the mode, then send 1B 01/02 05 06 for
--                                                           the effects that differ, or nothing (0x00541040)
--   Display names 5                                         local: Config's m_showUserName (also the N key)
--
-- s6-ui-settings: each row's action (kind optionrow, its row number) is frozen on the left press, as the pane acts on a
-- single left press (event type 1) and ignores a double press and the releases (review r1, finding 1). On a live session
-- the rules run it after the dispatcher's gates (TK.Core.Rules.OptionRules): the server's rows go to s6-rules-items'
-- sender, the local ones change on the logic thread, and what changed comes back as TK_LOCAL_OPTION, kept here in
-- settings.toml [options] (the map effects and the shadows are the world view's). Offline (the mock world) the same
-- switch runs here. A server row shows the server's state (Session.ServerOptions from 0x23 and 0x08, as the tab draws
-- Config's, OptionPane.cpp:880-953) and changes only when the server answers. The tab has no row for option 9; F12 is its
-- route (components/originalkeys).
--
-- The original's four keys for the switches the tab does not show (Shift+R, Shift+F10-F12) carry kind optionkey: the rules
-- turn the switch on every key-down, a repeat included, unless UserPane's gates pass the key on (review r1, findings 2 and
-- 4), and the line comes back the same way.
--
-- Wire: a row's press (Press, the optionrow action at the left press), the option keys' actions, and the opener's tab
-- switch (Toggle: UserPane::SwitchToOptionTab 0x005A4F40, before whoever draws the options) decide what is sent and when;
-- changing them changes what the server sees.

local H = __tk

TK.Game = TK.Game or {}
local O = { windows = {} }
TK.Game.Options = O

local function live() return H:IsLiveInput() end

-- ----- the local switches (settings.toml [options], Config's registry values) -----

--- A local switch's value.
function O.Get(key) return H:ClientSettingBool("options", key) end

--- Sets a local switch from a settings page or an interface's options: kept in settings.toml and handed to the session's
--- rules and drawing; the windows show it again.
function O.Set(key, on)
    H:ClientSettingSetBool("options", key, on and true or false)
    H:ClientSettingsSave()
    H:ApplyOptions()
    if key == "f1_swap" then O.ApplyF1Swap() end
    O.Refresh()
end

--- The System radio (Config::m_graphicsSetting): 0 Low, 1 High, 2 Manual.
function O.System() return H:ClientSettingInt("options", "graphics") end

-- the shared world view (s6-input round 49, separation step 4b: TK.WorldView, components/worldview)
local function worldview() return TK.WorldView end

--- The map's full-screen effects and the shadows: the world view's (its page has them too).
function O.MapEffects() local v = worldview() return v ~= nil and v:DB().mapEffects ~= false end
function O.Shadows() local v = worldview() return v ~= nil and v:DB().shadows ~= false end

-- The original's keys for four switches (UserPane::HandleKeyOrTextEvent, ui/UserPane.cpp:1491-1496 and 1745-1777): the
-- command, its name, the switch, its key's number for the rules (OptionRules), its default key, and its line in the system
-- messages.
O.KEYS = {
    { "TOGGLECLICKLOOK", "Right Click Look", "click_look", 1, "SHIFT-R", "Right click look :" },
    { "TOGGLESHOWDAMAGE", "Show Damage", "show_damage", 2, "SHIFT-F10", "Show Damage      :" },
    { "TOGGLETABVSWAP", "Tab / V Swap", "tab_v_swap", 3, "SHIFT-F11", "Tab, V Swap      :" },
    { "TOGGLECLICKMOVE", "Click to Move", "click_move", 4, "SHIFT-F12", "Click to move    :" },
}
local lines = {}
for _, k in ipairs(O.KEYS) do lines[k[3]] = k[6] end

--- What changed, kept and shown: name as settings.toml has it, value 0 or 1 (the radio 0-2), or -1 to turn it over.
--- A key's change writes 4a's line in the system messages, in the notices' colour (0x84).
function O.Keep(source, name, value)
    if name == "graphics" then
        H:ClientSettingSetInt("options", "graphics", value)
    elseif name == "map_effect" or name == "shadow" then
        local v = worldview()
        if v then
            local was
            if name == "map_effect" then was = O.MapEffects() else was = O.Shadows() end
            local on = value == 1 or (value == -1 and not was)
            if name == "map_effect" then v:SetMapEffects(on) else v:SetShadows(on) end
        end
    elseif name == "hear_snore" then
        -- m_hearSnoreMode (0-2, 1 by default): the row turns it to 1 from 0, to 0 from anything else, and says so
        -- (OptionPane.cpp:1032-1036).
        local mode = value
        if value == -1 then mode = H:ClientSettingInt("options", "hear_snore") == 0 and 1 or 0 end
        H:ClientSettingSetInt("options", "hear_snore", mode)
        if source == "row" then O.Say(mode ~= 0 and "Listen to snore  :YES" or "Listen to snore  :NO") end
    else
        local on = value == 1 or (value == -1 and not O.Get(name))
        H:ClientSettingSetBool("options", name, on)
        if source == "key" and lines[name] then O.Say(lines[name] .. (on and "ON" or "OFF")) end
        if name == "f1_swap" then O.ApplyF1Swap() end
    end
    H:ClientSettingsSave()
    O.Refresh()
end

--- A line in the system messages, as SystemMessagePane::AddColorStringMessage writes the options' notices in 0x84 on 0x24
--- (OptionPane.cpp:1034, UserPane.cpp:1495 and 1750-1772): by the rules' system lines' event (TK_RULES_MESSAGE, which
--- core/game/chat.lua colours so), so each interface shows it where its original does: 7.x's messages pane and not its
--- chat log, 5.x's message board while it shows, Modern's Notices. s6-ui-core round 86: it went by the client's lines'
--- event, which is the chat pane's (4a's screenshot notice, ScreenPane.cpp:432), so 7.x showed it in the chat log.
function O.Say(text)
    TK.FireEvent("TK_RULES_MESSAGE", text)
end

--- The F1/Shift+F1 swap (Config::m_f1Swap, row 24; UserPane::HandleKeyOrTextEvent, ui/UserPane.cpp:1659-1676): the Help
--- Menu (43 01) is on F1 with it on, on Shift+F1 with it off; the other key is the help pages, which this client never
--- opens (the head: K-078, O-21). The Help Menu's binding moves between the two keys when it is on the other one and
--- the key it goes to is free; a key the player bound it to elsewhere stays. Wire: it decides which of F1 and Shift+F1
--- sends the Help Menu's 43 01 (UserPane::HandleKeyOrTextEvent 0x005A5BD0); changing it changes what the server sees.
function O.ApplyF1Swap()
    local swap = O.Get("f1_swap")
    local to, from = swap and "F1" or "SHIFT-F1", swap and "SHIFT-F1" or "F1"
    if GetBindingAction(from) == "HELPMENU" and not GetBindingAction(to) then
        SetBinding(from, nil)
        SetBinding(to, "HELPMENU")
    end
end

TK.On("PLAYER_LOGIN", function() O.ApplyF1Swap() end)
TK.On("TK_PROFILE_CHANGED", function() O.ApplyF1Swap() end)

TK.On("TK_LOCAL_OPTION", function(_, source, name, value) O.Keep(source, name, value) end)

local labels = TK.Actions.labels
labels.optionkey = labels.optionkey or "Option"
labels.optionrow = labels.optionrow or "Game option"

for _, k in ipairs(O.KEYS) do
    -- Wire: on a live session the rules take the key, by its optionkey action (UserPane's gates, then the switch); offline
    -- nothing does, so the binding turns it here. Changing the action or its amount changes what the key does there.
    TK.Bindings:RegisterCommand(k[1], k[2], function()
        if TK.GameState:InWorld() and not live() then
            O.Keep("key", k[3], -1)
            H:ApplyOptions()
        end
    end, { kind = "optionkey", amount = k[4] })
    TK.DB.defaultBindings[k[5]] = k[1]
end

-- ----- Display names (Config::m_showUserName; s6-play-modes round 8, W6) -----

-- The original's N (MapPane::HandleKeyOrTextEvent, ui/MapPane.cpp:1420-1423: n with no modifier, Ctrl or Alt; Shift is
-- the inventory's) and the options tab's row 5 (OptionPane.cpp:1008) turn Config's m_showUserName over, a Config flag the
-- whole client draws by (ObjectPane.cpp:1121-1170), so it is one global setting (settings.toml options.show_user_name,
-- imported from ShowUserName), not an interface's: with Modern's nameplates off (7.x's and 5.x's profiles) N turned a
-- switch nothing drew by (W6). The drawing reads it (LocalOptions), Modern's nameplates too. Local: nothing is sent.

--- Whether names are displayed.
function O.ShowNames() return H:ClientSettingInt("options", "show_user_name") ~= 0 end

--- Sets Display names: kept in settings.toml and handed to the drawing; an open settings page and the windows show it.
function O.SetShowNames(on)
    H:ClientSettingSetInt("options", "show_user_name", on and 1 or 0)
    H:ClientSettingsSave()
    H:ApplyOptions()
    if TK.Settings:IsOpen() then TK.Settings:RefreshPage() end
    O.Refresh()
end

--- The original's n: Display names on or off.
function O.ToggleNames() O.SetShowNames(not O.ShowNames()) end

TK.Bindings:RegisterCommand("TOGGLENAMES", "Display Names", function() O.ToggleNames() end)
for _, key in ipairs({ "N", "CTRL-N", "ALT-N" }) do TK.DB.defaultBindings[key] = "TOGGLENAMES" end

-- ----- a row's press -----

--- The server's options as the logic last saw them, by name; nil without a live session.
function O.ServerState()
    local ok, weather, magic, advice, movement, sound, whispers, shouts, fixed = H:GetServerOptions()
    if not ok then return nil end
    return { weather = weather, magic = magic, advice = advice, movement = movement, sound = sound,
        whispers = whispers, shouts = shouts, fixed = fixed }
end

--- Offline (no rules): a row's local part, as OptionRules runs it on a live session.
function O.LocalRow(row)
    if row == 2 then O.Keep("row", "map_effect", -1); O.Keep("row", "graphics", 2)
    elseif row == 3 or row == 22 then O.Keep("row", "graphics", 2)
    elseif row == 14 then O.Keep("row", "double_click", -1)
    elseif row == 18 then O.Keep("row", "graphics", 2); O.Keep("row", "shadow", -1)
    elseif row == 19 then O.Keep("row", "graphics", 2); O.Keep("row", "balloon", -1)
    elseif row == 20 or row == 21 then
        local mode = row - 20
        for _, name in ipairs({ "graphics", "map_effect", "shadow", "balloon" }) do O.Keep("row", name, mode) end
    elseif row == 23 then O.Keep("row", "orb_target_share", -1)
    elseif row == 13 then O.Keep("row", "hear_snore", -1)
    elseif row == 24 then O.Keep("row", "f1_swap", -1)
    else return end
    H:ApplyOptions()
end

--- A left press on a row (its optionrow action frozen at the press, by whichever interface draws the row): on a live
--- session the rules run it; offline this side does. Wire: NewOptionPane::HandlePointerOrMouseEvent 0x00540910's single
--- left press; changing when this runs changes what the server sees.
function O.Press(row)
    TK.Actions:RunFrozen()
    if not live() then O.LocalRow(row) end
end

-- ----- the windows and the opener -----

-- An interface's own options window, under its panel (5.x's: interfaces/5x/panels/options), the latest provided asked
-- first: toggle() shows or hides it and returns true while its panel is in use, false otherwise (the next is asked).
-- The window used when none takes the opener (Modern's Game Options window, interfaces/modern/panels/windows since step
-- 7): { Toggle, Page, Refresh, IsOpen, panel }; Page(delta) is true when the open window turned its page; panel is its
-- switch ({ component, node, switch }, as the views' windows: s6-modular-g round 18, section 5.1), and while it is off the
-- window takes no opener.
local fallback

--- An interface's options window: toggle() returns true when it took the opener (its panel in use). panelId is its
--- panel's page (the node id).
function O.ProvideWindow(panelId, toggle)
    table.insert(O.windows, 1, TK.Mark({ panel = panelId, toggle = toggle }))
end

-- s6-interface-5x (round 13, the separation's step 11): a panel turned off takes its window with it, as the views' do
TK.OnWithdraw(function(name, panel) TK.DropOwned(O.windows, name, panel) end)

--- The window used when no provided window takes the opener.
local fallbackOwner -- its owner (TK.Mark), s6-modular-g (round 18)
function O.SetWindow(window) fallback, fallbackOwner = window, TK.Mark({}) end

-- s6-modular-g (round 18, step 11's kept = 7 dropped): the fallback goes with its component when that is unloaded (every
-- one of Modern's windows turned off), as a provided window does
TK.OnWithdraw(function(name, panel)
    if fallbackOwner and TK.OwnedBy(fallbackOwner, name, panel) then fallback, fallbackOwner = nil, nil end
end)

--- s6-modular-g (round 18): the fallback window while its switch is on, else nil.
local function fallbackOn()
    if fallback and (fallback.panel == nil or TK.Panels:IsOn(nil, fallback.panel)) then return fallback end
end

--- s6-modular-g (round 18; section 5.1): whether anything draws the options now: a side panel's page in use (the
--- views' "options"), an interface's own window whose panel is on, or the fallback while its switch is on.
local function drawn()
    if TK.Game.Views.Drawn("options") then return true end
    for _, w in ipairs(O.windows) do
        if TK.Panels:IsOn(nil, TK.Panels:OfNode(w.panel)) then return true end
    end
    return fallbackOn() ~= nil
end

--- The windows' rows shown again (a change from a key, a settings page or the server's answer).
function O.Refresh()
    if fallback and fallback.Refresh then fallback.Refresh() end
end

--- s6-modular-g (round 17, step 7): whether the fallback window is open (Modern's window). Drawing only.
function O.WindowOpen()
    return fallback ~= nil and fallback.IsOpen ~= nil and fallback.IsOpen() == true
end

--- The opener: F10 and an interface's options button.
function O.Toggle()
    if not TK.GameState:InWorld() then return end
    -- s6-modular-g (round 18; section 5.1): with nothing to draw the options (each page and window that could is turned
    -- off), the opener does nothing, not even its tab switch, as an unbound key and as the views' openers
    -- (TK.Game.Views.Open). Wire: 4a's F10 always switches (UserPane::SwitchToOptionTab 0x005A4F40; its one panel always
    -- draws the tab); here the tab stays as it was, so the group key's next press sends what it would have before F10.
    -- Changing this check changes what the server sees.
    if not drawn() then return end
    -- s6-modular-g (round 14 fix); s6-interface-5x (round 12, step 1): F10 and 7.x's tab strip button are 4a's options
    -- tab (UserPane::SwitchToOptionTab 0x005A4F40: SwitchActiveTab(6)), the game layer's one tab (core/game/sidepanel.lua)
    -- in every interface, whoever then draws the options; a side panel follows it. Wire: that tab decides whether the
    -- group's next press is a switch that sends 2D 01, and E and G's sender; changing it, or moving it after the windows
    -- below, changes what the server sees.
    TK.Game.SidePanel.Switch(6)
    -- s6-interface-7x-b (round 5): a side panel's page that draws the options (7.x's, interfaces/7x/panels/side/options.lua,
    -- the game layer's views' "options") shows them; then an interface's own options window while its panel is in use
    -- (5.x's); else the fallback. Drawing only: the opener sends nothing either way.
    if TK.Game.Views.Take("options", "input") then return end
    for _, w in ipairs(O.windows) do
        if w.toggle() then return end
    end
    local window = fallbackOn()
    if window then window.Toggle() end
end

TK.Bindings:RegisterCommand("TOGGLEGAMEOPTIONS", "Game Options", function() O.Toggle() end)
TK.DB.defaultBindings["F10"] = "TOGGLEGAMEOPTIONS"

-- PgUp and PgDn (K-097): the panels' paging command (PANELPAGEUP and PANELPAGEDOWN) is the game layer's views'
-- (core/game/views.lua, loaded first). The open options window pages first, as the tab that shows takes the key in the
-- original; otherwise the command runs as it was.
for _, p in ipairs({ { "PANELPAGEUP", "Previous Page (panels)", "PAGEUP", -1 },
    { "PANELPAGEDOWN", "Next Page (panels)", "PAGEDOWN", 1 } }) do
    local command, text, key, delta = p[1], p[2], p[3], p[4]
    local was = TK.Bindings.commands[command]
    local before = was and was.fn
    TK.Bindings:RegisterCommand(command, text, function()
        local paged = fallback ~= nil and fallback.Page ~= nil and fallback.Page(delta)
        if not paged and before then before() end
    end)
    if not was then TK.DB.defaultBindings[key] = command end
end

return O
