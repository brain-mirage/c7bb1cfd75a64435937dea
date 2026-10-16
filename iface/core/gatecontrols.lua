-- The gate's named controls (UI head note 51, s6-gate round 13). In gate mode (the gate's player, --capture) the gate's
-- driver clicks our controls by name: each named control's place is logged once laid out and again when it moves
-- (__tk:GateControl writes "[TK] gate control NAME LEFT,TOP WIDTHxHEIGHT", client pixels from the top left). Named: the
-- shown frames with a global TK name, and the dialog windows' controls as CLASS:INDEX, a list's rows as CLASS:INDEX:ROW
-- (the model's control index, as s6-rules-dialogs' windows number them). Outside gate mode nothing runs.

local H = __tk
if not H:GateMode() then return end

local function log(name, f)
    if not (f and f.__h and f:IsVisible()) then return end
    local l, b, w, h = TK.Util.RootRect(f)
    if not l or w <= 0 or h <= 0 then return end
    local s = TK.UIScale()
    H:GateControl(name, l * s, b * s, w * s, h * s)
end

-- UI head note 55 (s6-gate round 16): the popups' rows and the parcel pane's buttons are not in `controls`. Named by their
-- control index as tk-cli's tape counts them: MenuVarietySelectPane:8 is Ranking, ParcelPane:1 the letter button. The
-- rows are kept from 1, the buttons from 0.
local OTHERS = { MenuVarietySelectPane = { "rows", 1 }, RightButtonMenuPane = { "rows", 1 }, ParcelPane = { "buttons", 0 } }

-- s6-gate round 29 (UI round 33): controls with no global name, by the names its scenarios click: the Character tab's
-- switches and two buttons, the Game Options rows by the original's row number and the page arrows, the Settings tree's
-- rows by the node each shows now (recycled rows), and the emote buttons by the original's letter.
local SWITCHES = { exchange = "Exchange", group = "Group", helmet = "Helmet", necklace = "Necklace" }

local function logNamed()
    local cw = TK.CharacterWindow
    local tab = cw and cw.Tab and cw:Tab("character")
    local page = tab and tab.page
    if page then
        for id, name in pairs(SWITCHES) do log("TKCharacterSwitch" .. name, page.switches and page.switches[id]) end
        log("TKCharacterTakeOffAll", page.takeOffAll)
        log("TKCharacterBareHands", page.bare)
    end
    local options = _G.TKGameOptions
    if options then
        for key, row in pairs(options) do
            local n = type(key) == "string" and key:match("^optionrow(%d+)$")
            if n then log("TKGameOptionsRow" .. n, row) end
        end
        log("TKGameOptionsPageBack", options.back)
        log("TKGameOptionsPageNext", options.on)
    end
    for _, b in ipairs(TK.Settings and TK.Settings.treeButtons or {}) do
        if b.nodeId then log("TKSettingsNode:" .. b.nodeId, b) end
    end
    -- s6-modular (round 16): the open Settings page's controls by their names (spaces as _; a drop-down by its button), and
    -- the login screen's Settings button.
    for _, pw in ipairs(TK.Settings and TK.Settings.pageWidgets or {}) do
        local name, kind = pw[2].name, pw[2].type
        if type(name) == "string" and name ~= "" and kind ~= "description" and kind ~= "header" then
            log("TKSettingsControl:" .. name:gsub("%s+", "_"), pw[1].button or pw[1])
        end
    end
    log("TKLoginSettings", _G.TKLoginScreen and TKLoginScreen.settings)
    local emotes = _G.TKEmoteMenu
    if emotes then
        for _, e in ipairs(TK.Emotes and TK.Game.Emotes.list or {}) do log("TKEmoteButton" .. e[1]:upper(), emotes["emote" .. e[1]]) end
    end
end

local watcher = CreateFrame("Frame", nil, UIParent)
watcher:SetSize(1, 1)
watcher:SetScript("OnUpdate", TK.Util.Throttled(0.2, function()
    for name, f in pairs(_G) do
        if type(name) == "string" and name:sub(1, 2) == "TK" and type(f) == "table" and f.__h and f.IsVisible then log(name, f) end
    end
    logNamed()
    for _, win in pairs(TK.Dialogs.Windows()) do -- s6-characters (round 46, separation step 6)
        local class = win.className or "Dialog"
        for index, c in pairs(win.controls or {}) do
            log(class .. ":" .. index, c)
            if c.list then
                for row, r in ipairs(c.list.rows) do log(class .. ":" .. index .. ":" .. row, r) end
            end
        end
        local other = OTHERS[class]
        if other then
            for key, b in pairs(win[other[1]] or {}) do log(class .. ":" .. (key - other[2]), b) end
        end
    end
end))
