local C = TK.GetComponent("chatframe")
local H = __tk

C.defaults = TK.Visibility.Defaults({
    width = 430,
    height = 190,
    fontSize = 13,
    classicFont = true,
})

C.defaultPosition = { "BOTTOMLEFT", "BOTTOMLEFT", 20, 24 }

--- A switch kept in settings.toml (the original kept it in the registry) and handed to the session's rules.
local function rulesSwitch(section, key, name)
    return {
        type = "toggle", name = name,
        get = function() return H:ClientSettingBool(section, key) end,
        set = function(_, on)
            H:ClientSettingSetBool(section, key, on and true or false)
            H:ClientSettingsSave()
            H:ApplyChat()
            if C:Loaded() then C:ShowBar() end -- s6-interface-5x (round 13, step 11): the bar only while it is loaded
        end,
        default = function() return H:ClientSettingDefaultBool(section, key) end, -- s6-ui-settings: the page's reset
    }
end

C:StandardSettings("chatframe", {
    { type = "header", name = "Window" },
    { type = "range", key = "width", name = "Width", min = 200, max = 900, step = 5 },
    { type = "range", key = "height", name = "Height", min = 80, max = 600, step = 5 },
    -- s6-ui-settings (round 4): the background follows the Interface page's Panel Transparency (the shared panel style).
    { type = "toggle", key = "classicFont", name = "Classic Font" },
    { type = "range", key = "fontSize", name = "Font Size", min = 9, max = 20, step = 1,
      requires = { TK.Needs("Classic Font off", function(db) return not db.classicFont end) } }, -- s6-ui-core (round 54)
    { type = "description", name = "Classic Font draws the chat in the original's own bitmap font (12 pixels), when the game's data is installed." },
    -- s6-ui-chat: the tabs (tabs.lua, tabbar.lua), set from each tab's own menu as in WoW.
    { type = "header", name = "Tabs" },
    { type = "description", name = "Right-click a chat tab for its menu: Create New Window (on the first tab), Rename, Close, Lock, its own Font Size, and Settings, which chooses the messages it shows (say, shout, whisper, group, clan, subpath, broadcasts, system lines and notices, in any mix). Drag a tab to move it; a whisper makes a tab that shows whispers flash. Each character keeps its own tabs; Reset Chat Windows (on the first tab) brings back the default." },
    -- s6-play-modes (round 4): the Terminal tab (terminal.lua); round 6: the owner's short-text rule (2026-10-05)
    { type = "description", name = "Terminal (server commands): Add Terminal, in a tab's menu." },
    -- s6-ui-chat: the original's two talking options (O-02, the options tab's row 9; O-41, the chat bar's button 0).
    { type = "header", name = "Talking" },
    rulesSwitch("options", "say_with_enter", "Use Enter to Talk"),
    rulesSwitch("chat", "handle_left", "Back to Talk"),
    { type = "description", name = "Use Enter to Talk: Enter opens Talk's line; off, Enter does nothing. Back to Talk: after any line ' and a click on the typing area open Talk's line; off, the last mode's. As in the original, Back to Talk is on again at every start. The chat colours are set from the chat-mode button's menu (-Color-), in the game." },
}, { transparency = true }) -- s6-ui-core (round 53): its own transparency (TK.PanelTransparencyArgs)
