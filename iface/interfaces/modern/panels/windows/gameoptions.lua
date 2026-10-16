-- Modern's Game Options window (s6-modular-g round 17, separation step 7's last part; docs/development/
-- interface-separation.md, sections 4.3 and 5.8): the original's options tab (NewOptionPane, tab 6, opened by F10) as a
-- window of the tab's rows, moved unchanged from the Game Options component (components/gameoptions/main.lua), which
-- stays global with its settings page, F10 and the option keys. It is the game layer's fallback window
-- (TK.Game.Options.SetWindow): the opener shows it when no interface's own options page or window takes it, in every
-- interface while its switch is on (round 18: the Game Options Window page, settings.lua; off in 7.x's and 5.x's first
-- profiles, whose own pages draw the options). The rows' logic and their wire are the game layer's
-- (TK.Game.Options.Press): this file draws and places.
--
-- The tab's two pages: page 2 has rows 23-26 (here Orb and the F1 swap; 25 and 26 are the nameplates' settings), page
-- 1 the rest. The arrows and PgUp and PgDn turn them (K-097).

local C = TK.GetComponent("windows")
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local H = __tk
local O = TK.Game.Options

-- The window's own table (its page and functions), returned to its loader; the game layer asks its IsOpen
-- (TK.Game.Options.WindowOpen).
local M = {}

-- The server's rows: text, the original's row, and the state's name in TK.Game.Options.ServerState.
M.rows = {
    { "Magic Effects", 3, "magic" },
    { "Weather", 4, "weather" },
    { "Advice", 10, "advice" },
    { "Fixed Movement", 7, "fixed" },
    { "Hear Shouts", 11, "shouts" },
    { "Hear Whispers", 12, "whispers" },
    { "Sound Effects", 17, "sound" },
}

-- The local rows: text, the original's row, the state, and the tab's page (BuildOptionRows: page 0, or 1 for rows 23-26).
M.localRows = {
    { "Map Effects", 2, function() return O.MapEffects() end, 1 },
    { "Shadows", 18, function() return O.Shadows() end, 1 },
    { "Chat Balloon Fill", 19, function() return O.Get("balloon") end, 1 },
    { "Simple Click", 14, function() return not O.Get("double_click") end, 1 },
    { "Listen to Snore", 13, function() return H:ClientSettingInt("options", "hear_snore") ~= 0 end, 1 },
    { "Orb / Spell Target Share", 23, function() return O.Get("orb_target_share") end, 2 },
    { "F1 / Shift+F1 Swap (the Help Menu on F1)", 24, function() return O.Get("f1_swap") end, 2 },
}

local window

-- Its switch (Modern's panel gameoptions; section 5.1), as the other windows'.
local PANEL = { component = "windows", node = "gameoptionswindow", switch = "enabled" }

--- A row's box: its action runs from its press script (s6-ui-bag's press seam: the press's own record), so the release
--- has none and only shows the state again. Wire: the optionrow action, frozen and run at the left press
--- (TK.Game.Options.Press: NewOptionPane::HandlePointerOrMouseEvent 0x00540910); changing when it runs, or the row
--- number it carries, changes what the server sees.
local function row(parent, text, number, x, y)
    local c = W.Check(parent, text, function() M:Refresh() end)
    c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    TK.Actions:Set(c, "optionrow", nil, number)
    c:HookScript("OnMouseDown", function(_, button) if button == "LeftButton" then O.Press(number) end end)
    window["optionrow" .. number] = c
    return c
end

local function build()
    window = W.Window("TKGameOptions", "Game Options", 380, 440)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    C:Own(window)
    -- The tab's two pages (NewOptionPane: field_12B8 = 2), each row on its own (BuildOptionRows); the arrows (rows 0
    -- and 1) and PgUp and PgDn (HandleKeyOrTextEvent, OptionPane.cpp:963) turn them.
    window.pages = {}
    for p = 1, 2 do
        local f = CreateFrame("Frame", nil, window)
        f:SetAllPoints(window)
        window.pages[p] = f
    end
    local first, second = window.pages[1], window.pages[2]
    local more = W.Label(second, "This computer:", 12, { 0.75, 0.75, 0.75 }, "LEFT")
    more:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -40)
    local note = W.Label(first, "Kept by the server: a click asks it to turn the option over.", 12, { 0.75, 0.75, 0.75 }, "LEFT")
    note:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -40)
    window.rows = {}
    for i, r in ipairs(M.rows) do
        -- The box shows the server's state, not the click: it changes when the server answers.
        window.rows[i] = row(first, r[1], r[2], 18 + ((i - 1) % 2) * 172, -62 - math.floor((i - 1) / 2) * 28)
    end
    local here = W.Label(first, "This computer:", 12, { 0.75, 0.75, 0.75 }, "LEFT")
    here:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -184)
    window.locals = {}
    local placed = { 0, 0 }
    for i, r in ipairs(M.localRows) do
        -- Page 1's local rows in two columns under the server's; page 2's in one.
        local p, n = r[4], placed[r[4]]
        placed[p] = n + 1
        if p == 1 then
            window.locals[i] = row(first, r[1], r[2], 18 + (n % 2) * 172, -206 - math.floor(n / 2) * 28)
        else
            window.locals[i] = row(second, r[1], r[2], 18, -62 - n * 28)
        end
    end
    local system = W.Label(first, "System:", 12, { 0.75, 0.75, 0.75 }, "LEFT")
    system:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -326)
    window.system = {}
    for mode, text in ipairs({ "Low", "High", "Manual" }) do
        window.system[mode - 1] = row(first, text, 19 + mode, 18 + (mode - 1) * 110, -346)
    end
    local hint = W.Label(first, "Low and High also set magic and weather on the server.", 11, { 0.6, 0.6, 0.6 }, "LEFT")
    hint:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 18, 40)
    -- s6-ui-core (round 62; s6-optimize's plan step 4): the page arrows are the shared stepper (W.Stepper), the page
    -- between them; its parts keep their names (window.back, window.on, window.pageLabel). Changing a page sends nothing.
    local pages = W.Stepper(window, nil, function(step) M:Page(step) end, { valueWidth = 72, size = 11, colour = { 0.6, 0.6, 0.6 } })
    pages:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 12)
    window.back, window.on, window.pageLabel = pages.back, pages.forward, pages.value
    M:ShowPage(M.page or 1)
    -- The server's answer comes as 0x23 or in 0x08: an open window looks a few times a second.
    local elapsed = 0
    window:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed < 0.2 then return end
        elapsed = 0
        M:Refresh()
    end)
    -- s6-rules-dialogs. Wire: while the options tab shows, the server's "saved" (S 0x21) opens the tab's modal alert in
    -- place of the saved notice (NewOptionPane::HandlePacketEvent 0x00540DB0); until it closes it takes the keys, and a
    -- click outside it goes on to the side panel (DialogPane::HandlePointerOrMouseEvent 0x0049E240). Changing when these
    -- two hooks run changes what the client sends after a 0x21.
    window:HookScript("OnShow", function() __tk:DialogOptionPageShown(true); M:Refresh() end)
    window:HookScript("OnHide", function() __tk:DialogOptionPageShown(false) end)
end

--- Shows one of the tab's pages (kept while the window is closed, as the tab keeps field_12B9).
function M:ShowPage(p)
    self.page = p
    for i, f in ipairs(window.pages) do f:SetShown(i == p) end
    window.pageLabel:SetText("Page " .. p .. " of 2")
end

--- MoveSelection (OptionPane.cpp:1375-1392): a page back or on, within the two. True when the window is open, so the
--- panels' PgUp and PgDn (K-097) stop here.
function M:Page(delta)
    if not self:IsOpen() then return false end
    local p = math.max(1, math.min(2, (self.page or 1) + delta))
    self:ShowPage(p)
    return true
end

--- Shows the states: the server's rows, the local rows and the radio.
function M:Refresh()
    if not window or not window:IsShown() then return end
    local state = O.ServerState()
    for i, r in ipairs(self.rows) do window.rows[i]:SetChecked(state ~= nil and state[r[3]] == 1) end
    for i, r in ipairs(self.localRows) do window.locals[i]:SetChecked(r[3]() and true or false) end
    local mode = O.System()
    for m, c in pairs(window.system) do c:SetChecked(m == mode) end
end

function M:IsOpen() return window ~= nil and window:IsShown() end

--- Closes the window when its switch is turned off (the windows' ApplySettings, as TK.Game.Views.CloseOff). Nothing is
--- sent.
function M:CloseOff()
    if self:IsOpen() and not TK.Panels:IsOn(nil, PANEL) then window:Hide() end
end

--- The window, built if needed (tests).
function M:Window()
    if not window then build() end
    return window
end

-- The game layer's fallback window: the opener shows it when no interface's own options window takes it, while its switch
-- is on (drawing only).
O.SetWindow({
    panel = PANEL,
    Toggle = function()
        if not window then build() end
        window:Toggle()
    end,
    Page = function(delta) return M:Page(delta) end,
    Refresh = function() M:Refresh() end,
    IsOpen = function() return M:IsOpen() end, -- s6-modular-g (round 17): TK.Game.Options.WindowOpen asks it
})

-- s6-ui-core (round 86, round 85's final review, P2): open at the interfaces' form switch, it opens again on its page
-- (TK.Interfaces:KeepAcrossForms), shown without the opener's tab switch (TK.Game.Options.Toggle's SidePanel.Switch(6)),
-- so nothing is sent and the active tab stays as it was. Wire: its OnShow marks the option page shown again, as before the
-- switch (a 0x21's alert, NewOptionPane::HandlePacketEvent 0x00540DB0); changing this changes what the client sends after
-- a 0x21.
TK.Interfaces:KeepAcrossForms("gameoptions", function() return M:IsOpen() and (M.page or 1) or nil end, function(page)
    if not window then build() end
    M:ShowPage(page)
    window:Show()
end)

return M
