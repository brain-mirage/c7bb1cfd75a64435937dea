-- s6-ui-chat (chat tabs): the chat frame's tab strip, behaving as WoW's docked chat windows do (behaviour only).
-- A click shows a tab; a right-click opens its menu: Lock Window, Rename Window, on the first tab Create New Window and
-- Reset Chat Windows, Close Window on the others, Add or Close Terminal (s6-play-modes: terminal.lua), its font size and
-- its Settings (the kinds it shows). A drag moves a
-- tab along the strip (the first stays first, a locked tab stays put). A whisper flashes a tab that shows whispers
-- until it is shown.
--
-- The strip's art and layout are here; what the tabs do is tabs.lua's, and the chat frame (main.lua) applies it.

local C = TK.GetComponent("chatframe")
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local T = require("interfaces.modern.panels.chatframe.tabs")

local B = {}

local HEIGHT, GAP, PAD, MIN_WIDTH = 22, 2, 20, 56

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

-- s6-ui-core (round 61): the chat's tabs are the shared tab (core/widgets.lua) in their own see-through colours: the
-- shown one lighter with gold text, the others grey
local LOOK = { bg = { 0.14, 0.14, 0.16, 0.7 }, chosenBg = { 0.3, 0.3, 0.33, 0.9 }, text = W.grey, chosenText = W.gold }

local function tabButton(strip, k)
    local b = W.Tab(strip, "", MIN_WIDTH, HEIGHT, nil, { name = "TKChatTab" .. k, look = LOOK })
    b.glow = b:CreateTexture(nil, "ARTWORK")
    b.glow:SetAllPoints(b)
    b.glow:SetTexture("tk:glow")
    b.glow:SetVertexColor(1, 0.85, 0.4, 1)
    b.glow:Hide()
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            B:OpenMenu(self.index)
        else
            C:SelectTab(self.index)
        end
    end)
    b:SetScript("OnDragStart", function(self)
        local tab = T.tabs[self.index]
        if self.index == 1 or not tab or tab.locked then return end
        strip.dragging = self.index
        self:SetAlpha(0.6)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetAlpha(1)
        local from = strip.dragging
        strip.dragging = nil
        if from then C:MoveTab(from, dropIndex(strip, from)) end
    end)
    return b
end

--- The strip, along the top of the chat frame f.
function B:Build(f)
    local strip = CreateFrame("Frame", "TKChatTabs", f)
    strip:SetHeight(HEIGHT)
    strip:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 0)
    strip.buttons = {}
    -- WoW's alert: the tab's glow fades in and out, a second each way, until the tab is shown.
    -- s6-optimize (round 10): the alert (Lua) is looked at first; the time and the tab's IsShown are read only for one.
    strip:SetScript("OnUpdate", function()
        local a
        for k, b in ipairs(strip.buttons) do
            if T.tabs[k] and T.tabs[k].alert and b:IsShown() then
                a = a or 0.5 - 0.5 * math.cos(GetTime() * math.pi)
                b.glow:SetAlpha(a * 0.5)
            end
        end
    end)
    self.strip = strip
    return strip
end

--- The tabs as the logic has them: names, order, the one shown, the alerting ones.
function B:Refresh()
    local strip = self.strip
    if not strip then return end
    local prev
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
        b:Show()
        prev = b
    end
    for k = #T.tabs + 1, #strip.buttons do strip.buttons[k]:Hide() end
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

local function buildSettings()
    local s = W.Window("TKChatTabSettings", "Chat Settings", 360, 300)
    -- s6-interface-5x (round 14; Astra's review of round 13, P2): the shared widgets make it on UIParent, which makes it
    -- no panel's until owned, so it goes with the chat frame when it is unloaded
    C:Own(s)
    s.window = W.Label(s, "", 13, W.white)
    s.window:SetPoint("TOP", s.title, "BOTTOM", 0, -8)
    s.checks = {}
    local columns = { Chat = { x = 24, y = -78 }, Other = { x = 192, y = -78 } }
    for group, at in pairs(columns) do
        local h = W.Header(s, group, 140)
        h:SetPoint("TOPLEFT", s, "TOPLEFT", at.x, at.y + 24)
    end
    for _, k in ipairs(T.KINDS) do
        local at = columns[k.group]
        local c = W.Check(s, k.label, function(on) C:SetTabShows(s.tab, k.key, on) end)
        c:SetPoint("TOPLEFT", s, "TOPLEFT", at.x, at.y)
        at.y = at.y - 28
        s.checks[k.key] = c
    end
    s.done = W.Button(s, "Okay", 100, 24, "red", function() s:Hide() end)
    s.done:SetPoint("BOTTOM", s, "BOTTOM", 0, 14)
    return s
end

--- The window for tab k: one check box a kind, ticked for what the tab shows.
function B:OpenSettings(k)
    local tab = T.tabs[k]
    if not tab then return end
    settings = settings or buildSettings() -- buildSettings makes it the chat frame's (C:Own, s6-interface-5x round 14)
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

-- s6-ui-core (round 86, round 85's final review, P2): open at the interfaces' form switch, it opens again for its tab
-- (TK.Interfaces:KeepAcrossForms). Drawing only: nothing is sent.
TK.Interfaces:KeepAcrossForms("chatsettings", function() return settings and settings:IsShown() and settings.tab or nil end,
    function(k) B:OpenSettings(k) end)

return B
