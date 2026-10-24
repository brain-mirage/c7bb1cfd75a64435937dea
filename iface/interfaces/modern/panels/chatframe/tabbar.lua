-- s6-ui-chat (chat tabs): the chat frame's tab strip, behaving as WoW's docked chat windows do (behaviour only).
-- A click shows a tab; a right-click opens its menu: Lock Window, Rename Window, on the first tab Create New Window and
-- Reset Chat Windows, Close Window on the others, Add or Close Terminal (s6-play-modes: terminal.lua), its font size and
-- its Settings (the kinds it shows). A drag moves a
-- tab along the strip (the first stays first, a locked tab stays put). A whisper flashes a tab that shows whispers
-- until it is shown.
--
-- The strip's art and layout are tabbar.xml's (s6-ui-core round 85, the XML twin; core/xml.md); what the tabs do is
-- tabs.lua's, and the chat frame (main.lua) applies it.

local C = TK.GetComponent("chatframe")
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local T = require("interfaces.modern.panels.chatframe.tabs")

local B = {}

-- the scripts tabbar.xml names, and its build (its templates: the strip, a tab, the settings window)
local scripts = {}
local ui = TK.Xml.Load("tabbar.xml", { scripts = scripts, elements = require("interfaces.modern.elements") })

local GAP, PAD, MIN_WIDTH = ui.SIZES.gap, ui.SIZES.pad, ui.SIZES.minWidth

local function cursorX()
    local x = GetCursorPosition()
    return x / TK.UIScale()
end

--- The place tab from goes when dropped, counted with it taken out (as T:Move inserts): before the first other tab
--- whose middle is right of the cursor (never before the first).
local function dropIndex(strip, from)
    local x, to = cursorX(), 2
    for k = 2, #T.tabs do
        if k ~= from then
            local l, _, w = TK.Util.RootRect(strip.buttons[k])
            if l and x < l + w / 2 then break end
            to = to + 1
        end
    end
    return to
end

function scripts.TabClick(self, button)
    if button == "RightButton" then
        B:OpenMenu(self.index)
    else
        C:SelectTab(self.index)
    end
end

function scripts.TabDragStart(self)
    local tab = T.tabs[self.index]
    if self.index == 1 or not tab or tab.locked then return end
    self:GetParent().dragging = self.index
    self:SetAlpha(0.6)
end

function scripts.TabDragStop(self)
    local strip = self:GetParent()
    self:SetAlpha(1)
    local from = strip.dragging
    strip.dragging = nil
    if from then C:MoveTab(from, dropIndex(strip, from)) end
end

-- WoW's alert: the tab's glow fades in and out, a second each way, until the tab is shown.
-- s6-optimize (round 10): the alert (Lua) is looked at first; the time and the tab's IsShown are read only for one.
function scripts.Alerts(strip)
    local a
    for k, b in ipairs(strip.buttons) do
        if T.tabs[k] and T.tabs[k].alert and b:IsShown() then
            a = a or 0.5 - 0.5 * math.cos(GetTime() * math.pi)
            b.glow:SetAlpha(a * 0.5)
        end
    end
end

local function tabButton(strip, k) return ui:New("Tab", strip, "TKChatTab" .. k) end

--- The strip, along the top of the chat frame f.
function B:Build(f)
    self.strip = ui:New("Strip", f)
    return self.strip
end

--- The tabs as the logic has them: names, order, the one shown, the alerting ones.
function B:Refresh()
    local strip = self.strip
    if not strip then return end
    local prev, alerting = nil, false
    for k, tab in ipairs(T.tabs) do
        local b = strip.buttons[k] or tabButton(strip, k)
        strip.buttons[k] = b
        b.index = k
        b:SetText(tab.name)
        b:SetWidth(math.max(MIN_WIDTH, b:GetFontString():GetStringWidth() + PAD))
        b:ClearAllPoints()
        if prev then b:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", GAP, 0) else b:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 0) end
        local shown = k == T.selected
        b:SetSelected(shown)
        b.glow:SetShown(tab.alert and not shown)
        alerting = alerting or (tab.alert and not shown)
        b:Show()
        prev = b
    end
    for k = #T.tabs + 1, #strip.buttons do strip.buttons[k]:Hide() end
    TK.Util.Updating(strip, alerting) -- s6-ui-core (round 101, T11 step 4): the pulse runs only while a glow shows
end

-- ----- the tab's menu -----

local function namePrompt(title, default, onOk)
    W.Prompt({ title = title, text = "Enter chat window name", maxLetters = T.NAME_LETTERS, default = default, onOk = onOk })
end

--- WoW's chat tab menu, in its order, for tab k.
function B:OpenMenu(k)
    local tab = T.tabs[k]
    if not tab then return end
    local entries = {
        { text = tab.locked and "Unlock Window" or "Lock Window", onClick = function() C:LockTab(k, not tab.locked) end },
        { text = "Rename Window", onClick = function() namePrompt("Rename Window", tab.name, function(v) C:RenameTab(k, v) end) end },
    }
    if k == 1 then
        entries[#entries + 1] = { text = "Create New Window", disabled = #T.tabs >= T.MAX_TABS,
            onClick = function() namePrompt("Create New Window", "", function(v) C:CreateTab(v) end) end }
        entries[#entries + 1] = { text = "Reset Chat Windows", onClick = function()
            W.Confirm("This will reset your chat windows to default settings.\nYou will lose any custom settings.",
                function() C:ResetTabs() end)
        end }
    elseif not tab.terminal then -- s6-play-modes (round 6, s6-optimize's H10): the Terminal tab's is Close Terminal, below
        entries[#entries + 1] = { text = "Close Window", onClick = function() C:CloseTab(k) end }
    end
    -- s6-play-modes (round 4): the Terminal tab (terminal.lua), never there by default: added and closed from any tab's menu
    local terminal = T:TerminalIndex()
    entries[#entries + 1] = terminal and { text = "Close Terminal", onClick = function() C:CloseTab(terminal) end }
        or { text = "Add Terminal", disabled = #T.tabs >= T.MAX_TABS, onClick = function() C:AddTerminal() end }
    entries[#entries + 1] = { text = "Font Size", title = true }
    local sizes = { 0 }
    for _, s in ipairs(T.FONT_SIZES) do sizes[#sizes + 1] = s end
    for _, s in ipairs(sizes) do
        local text = s == 0 and "Default" or (s .. " pt")
        if tab.fontSize == s then text = "\u{2022} " .. text end
        entries[#entries + 1] = { text = text, onClick = function() C:SetTabFontSize(k, s) end }
    end
    entries[#entries + 1] = { text = "Filters", title = true }
    entries[#entries + 1] = { text = "Settings", onClick = function() B:OpenSettings(k) end }
    W.OpenMenu(entries) -- at the cursor, as WoW's
    -- The strip sits low: a menu that would run under the screen's bottom opens upward from the cursor, as WoW's do;
    -- TK.FitToScreen keeps all of it on the screen either way.
    local _, bottom = TK.Util.RootRect(TKContextMenu)
    if bottom and bottom < 0 then
        TKContextMenu:ClearAllPoints()
        TKContextMenu:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", TK.Util.CursorRoot())
    end
    TK.FitToScreen(TKContextMenu)
end

-- ----- the settings window: which kinds the tab shows (WoW's Chat Settings, messages as check boxes) -----

local settings

function scripts.Own(s) C:Own(s) end

-- the kinds' check boxes, in the logic's order (T.KINDS), each down its group's column (COLUMNS), 28 apart
function scripts.Checks(s, build)
    local y = {}
    for group, at in pairs(ui.COLUMNS) do y[group] = at.y end
    for _, k in ipairs(T.KINDS) do
        local c = build:New("KindCheck", s, nil, nil, k) -- (its label: KindCheck's @with.label)
        c.onChange = function(on) C:SetTabShows(s.tab, k.key, on) end
        c:SetPoint("TOPLEFT", s, "TOPLEFT", ui.COLUMNS[k.group].x, y[k.group])
        y[k.group] = y[k.group] - 28
        s.checks[k.key] = c
    end
end

function scripts.HideSettings(b) b:GetParent():Hide() end

--- The window for tab k: one check box a kind, ticked for what the tab shows.
function B:OpenSettings(k)
    local tab = T.tabs[k]
    if not tab then return end
    settings = settings or ui:New("Settings") -- the chat frame's (its Own, s6-interface-5x round 14)
    settings.tab = k
    settings.window:SetText("Window: " .. tab.name)
    for key, c in pairs(settings.checks) do c:SetChecked(tab.kinds[key] == true) end
    settings:Show()
end

--- The settings window, while open, shows its tab's name as it is now (a rename).
function B:SettingsFollow()
    local tab = settings and settings:IsShown() and T.tabs[settings.tab]
    if tab then settings.window:SetText("Window: " .. tab.name) end
end

--- Closed when the tabs change places (a move, a close, a new layout), so it never edits another tab.
function B:CloseSettings()
    if settings then settings:Hide() end
end

return B
