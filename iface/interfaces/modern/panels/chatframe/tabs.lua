-- s6-ui-chat (chat tabs, the owner 2026-10-03): the chat frame's tabs, behaving as WoW's chat windows do (WoW is a
-- reference for behaviour only). Each tab shows its own choice of NexusTK's message kinds, keeps its own lines, font
-- size and lock, and the set of tabs is saved per character. Nothing sent changes: a tab only chooses what is shown.
--
-- This file is the tabs' logic, with no frames: the kinds, which kind a line is, each tab's lines, and the saved form.
-- The tab strip, its menu and the settings window are tabbar.lua's.

local T = {}

T.MAX_TABS = 10                    -- WoW's ten chat windows
T.MAX_LINES = 1000                 -- each tab's log, as the original's chat pane's (List(4, 1000))
T.NAME_LETTERS = 31                -- WoW's name box
T.FONT_SIZES = { 12, 14, 16, 18 }  -- WoW's chat font sizes

--- NexusTK's message kinds, as the settings window lists them: "Chat", the players' lines; "Other", the rest.
T.KINDS = {
    { key = "say", label = "Say", group = "Chat" },                     -- 0x0D kinds 0 and 3
    { key = "shout", label = "Shout", group = "Chat" },                 -- 0x0D kind 1: a shout nearby, its speaker known
    { key = "whisper", label = "Whisper", group = "Chat" },             -- 0x0A kind 0
    { key = "group", label = "Group", group = "Chat" },                 -- 0x0A kind 11
    { key = "clan", label = "Clan", group = "Chat" },                   -- 0x0A kind 12
    { key = "subpath", label = "Subpath", group = "Chat" },             -- 0x0A kind 11 in the subpath's "<@NAME>" form
    { key = "broadcast", label = "Broadcast", group = "Other" },        -- 0x0A kind 4: the shout-type line, no speaker
    { key = "colored", label = "Coloured Lines", group = "Other" },     -- 0x0A kind 18, 0x0D kind 4: the packet's colours
    { key = "system", label = "System", group = "Other" },              -- 0x0A kind 5, and the client's own lines
    { key = "notice", label = "Notices", group = "Other" },             -- 0x0A kinds 2 and 3, the rules' item notices
}
T.KIND = {}
for _, k in ipairs(T.KINDS) do T.KIND[k.key] = k end

-- s6-play-modes (round 4): the Terminal's own lines (its typed lines, the server console's output; terminal.lua): a kind
-- only the Terminal tab shows, so it is not in the list a tab's settings window offers. The Terminal tab also shows the
-- server's answers to its commands (notices, system lines).
T.KIND.terminal = { key = "terminal", label = "Terminal", group = "Other" }
T.TERMINAL_KINDS = { "terminal", "notice", "system" }

-- A new tab listens to the players' lines, as a new WoW window listens to say, yell, guild, whisper, party and channels.
local NEW_KINDS = { "say", "shout", "whisper", "group", "clan", "subpath" }

--- The kind of a line the session hands the chat (TK_CHAT_MESSAGE's channel, the speaker, the text as it came).
--- 0x0A kind 4 and 0x0D kind 1 share the "shout" channel; only 0x0D's carry a speaker. Subpath lines come as group
--- lines (kind 11) in the form "<@NAME> (Class) text", as the test server sends them; any other form stays Group.
function T.Classify(channel, speaker, text)
    if channel == "shout" then return (speaker and speaker ~= 0) and "shout" or "broadcast" end
    if channel == "group" and type(text) == "string" and text:sub(1, 2) == "<@" then return "subpath" end
    if T.KIND[channel] then return channel end
    return "system"
end

local function kindSet(keys)
    local set = {}
    for _, k in ipairs(keys) do
        if T.KIND[k] then set[k] = true end
    end
    return set
end

local function allKinds()
    local keys = {}
    for _, k in ipairs(T.KINDS) do keys[#keys + 1] = k.key end
    return keys
end

local function newTab(name, keys)
    return { name = name, kinds = kindSet(keys), fontSize = 0, locked = false, lines = {}, offset = 0, alert = false }
end

local function wipe(list)
    for i = #list, 1, -1 do list[i] = nil end
end

local function push(list, entry)
    list[#list + 1] = entry
    if #list > T.MAX_LINES then table.remove(list, 1) end
end

-- The session's lines, every kind, for the tabs of a layout loaded later (the login's lines come before the world).
T.all = {}

--- The default layout: General, showing every kind, as the chat frame showed before it had tabs. WoW's default also
--- has a Combat Log, which NexusTK has nothing for.
function T:Reset()
    self.tabs = { newTab("General", allKinds()) }
    self.selected = 1
    self:Refill()
end

--- Each tab's lines again, from the session's (a layout loaded or reset).
function T:Refill()
    for _, tab in ipairs(self.tabs) do
        tab.lines, tab.offset, tab.alert = {}, 0, false
        for _, e in ipairs(self.all) do
            if tab.kinds[e.kind] then tab.lines[#tab.lines + 1] = e end
        end
    end
end

--- A new game screen: no lines anywhere.
function T:Clear()
    wipe(self.all)
    for _, tab in ipairs(self.tabs) do
        wipe(tab.lines)
        tab.offset, tab.alert = 0, false
    end
end

--- A line ({ text, rgb, outline, kind }): into the session's lines and every tab that shows its kind. keep: the views
--- stay where they are (Shift held, as the original's chat pane keeps its view). A whisper sets a tab that shows it and
--- is not the one shown alerting, as WoW flashes it.
function T:Add(entry, keep)
    push(self.all, entry)
    for i, tab in ipairs(self.tabs) do
        if tab.kinds[entry.kind] then
            push(tab.lines, entry)
            tab.offset = keep and math.min(tab.offset + 1, #tab.lines - 1) or 0
            if entry.kind == "whisper" and i ~= self.selected then tab.alert = true end
        end
    end
end

function T:Current() return self.tabs[self.selected] end

--- Shows tab i: its alert ends.
function T:Select(i)
    if not self.tabs[i] then return false end
    self.selected = i
    self.tabs[i].alert = false
    return true
end

--- A name as typed: trimmed, at most 31 letters; nil for nothing.
function T.CleanName(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    return name:sub(1, T.NAME_LETTERS)
end

--- A new tab after the others, listening to the players' lines, empty and shown (WoW's Create New Window); its name
--- "Chat N" when none is given. nil at ten tabs.
function T:Create(name)
    if #self.tabs >= T.MAX_TABS then return nil end
    table.insert(self.tabs, newTab(T.CleanName(name) or ("Chat " .. (#self.tabs + 1)), NEW_KINDS))
    self.selected = #self.tabs
    return #self.tabs
end

--- s6-play-modes (round 4): the Terminal tab's place, or nil when there is none (at most one).
function T:TerminalIndex()
    for i, tab in ipairs(self.tabs) do
        if tab.terminal then return i end
    end
    return nil
end

--- s6-play-modes (round 4): the Terminal tab after the others, empty and shown; nil when there is one or ten tabs. It
--- closes as any other tab (T:Close).
function T:AddTerminal()
    if self:TerminalIndex() or #self.tabs >= T.MAX_TABS then return nil end
    local tab = newTab("Terminal", T.TERMINAL_KINDS)
    tab.terminal = true
    table.insert(self.tabs, tab)
    self.selected = #self.tabs
    return #self.tabs
end

--- Closes tab i; the first cannot be closed. Closing the tab shown shows the first (its alert ends).
function T:Close(i)
    if i <= 1 or i > #self.tabs then return false end
    table.remove(self.tabs, i)
    if self.selected == i then
        self:Select(1)
    elseif self.selected > i then
        self.selected = self.selected - 1
    end
    return true
end

--- Renames tab i; an empty name keeps the old one.
function T:Rename(i, name)
    local clean = T.CleanName(name)
    if not clean or not self.tabs[i] then return false end
    self.tabs[i].name = clean
    return true
end

--- Moves tab i to place to (the first tab stays first, a locked tab stays where it is); the shown tab stays shown.
function T:Move(i, to)
    local n = #self.tabs
    if i <= 1 or i > n or self.tabs[i].locked then return false end
    to = math.max(2, math.min(to, n))
    if to == i then return false end
    local shown = self.tabs[self.selected]
    table.insert(self.tabs, to, table.remove(self.tabs, i))
    for k, tab in ipairs(self.tabs) do
        if tab == shown then self.selected = k end
    end
    return true
end

--- Whether tab i shows a kind, and changing it; the tab's lines so far stay as they are (WoW's windows take a newly
--- chosen kind from its next line on).
function T:Shows(i, kind) return self.tabs[i] ~= nil and self.tabs[i].kinds[kind] == true end

function T:SetShows(i, kind, on)
    local tab = self.tabs[i]
    if not tab or not T.KIND[kind] then return false end
    tab.kinds[kind] = on and true or nil
    return true
end

-- ----- the saved form: characters/<name>/chat.json -----

--- The layout to save: { version = 1, tabs = { { name, kinds = { keys }, fontSize, locked, terminal } } } (s6-play-modes:
--- terminal only on the Terminal tab, whose own kind it implies).
function T:Saved()
    local tabs = {}
    for _, tab in ipairs(self.tabs) do
        local kinds = {}
        for _, k in ipairs(T.KINDS) do
            if tab.kinds[k.key] then kinds[#kinds + 1] = k.key end
        end
        tabs[#tabs + 1] = { name = tab.name, kinds = kinds, fontSize = tab.fontSize, locked = tab.locked, terminal = tab.terminal }
    end
    return { version = 1, tabs = tabs }
end

local function validSize(size)
    if size == 0 then return true end
    for _, s in ipairs(T.FONT_SIZES) do
        if s == size then return true end
    end
    return false
end

--- A saved layout, or the default when there is none or it cannot be used (nil data: no layout yet). Each tab's lines
--- come from the session's. Returns false when saved data was not usable.
function T:Load(data)
    local tabs = {}
    if type(data) == "table" and data.version == 1 and type(data.tabs) == "table" then
        for _, t in ipairs(data.tabs) do
            local name = type(t) == "table" and type(t.name) == "string" and T.CleanName(t.name)
            if not name or type(t.kinds) ~= "table" or #tabs >= T.MAX_TABS then
                tabs = nil
                break
            end
            local tab = newTab(name, {})
            for _, k in ipairs(t.kinds) do
                if type(k) == "string" and T.KIND[k] then tab.kinds[k] = true end
            end
            local size = tonumber(t.fontSize) or 0
            tab.fontSize = validSize(size) and size or 0
            tab.locked = t.locked == true
            if t.terminal == true then tab.terminal, tab.kinds.terminal = true, true end -- s6-play-modes: with its own kind
            tabs[#tabs + 1] = tab
        end
    end
    if not tabs or #tabs == 0 then
        self:Reset()
        return data == nil
    end
    self.tabs = tabs
    self.selected = 1
    self:Refill()
    return true
end

T:Reset()

return T
