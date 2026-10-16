-- The chat frame: the original's chat pane (ChattingPane) and, under it, its chat bar (ChattingHandlePane): Back to Talk,
-- the chat-mode button with its menu, and the typing area.
--
-- The log (coverage rows G-31, C-13, K-099): the server's lines (0x0A, 0x0D; TK_CHAT_MESSAGE), newest at the bottom, at
-- most 1000 (List(4, 1000), ChattingPane.cpp:44 and :105-109), coloured as the original's chat pane colours them (the
-- colour pairs: core/chat.lua). The wheel, Shift+Up and Shift+Down scroll it a line, Shift+Page Up and Shift+Page Down a
-- page (ChattingPane::HandleKeyOrTextEvent 0x0047F6F0); a new line brings it back to the bottom unless Shift is held
-- (AddIncomingMessage 0x0047F370). Shift with the walk keys up and down never walks: the rules take it (ChatRules).
--
-- The keys and the menu (C-01 to C-06, K-035 to K-039, K-069): live they are the rules' (ChatRules): Enter opens Talk's
-- line (with Use Enter to Talk), / Talk's line with / in it, ' the say mode's line (Talk's with Back to Talk on), ! Shout's,
-- " Whisper's "To" line, Alt+c the line that stays open; the menu's rows set the mode and open its line, and -Color- opens
-- the colour dialog (the dialog model's ChattingColorPane, modal as the original's). The frame draws the logic's text line
-- in the typing area, where the original draws every LineInputPane (LineInputPane.cpp:46), and shows the rules' say mode.
-- Offline (the mock world) the line is the frame's own box, and nothing is sent.
--
-- The server's popups (0x0A kind 8) open a notice box instead of a line, and its message pane (0x58) shows at the
-- top of the screen until the server closes it.
--
-- s6-ui-chat (chat tabs, the owner 2026-10-03): the log has tabs, as WoW's chat windows (tabs.lua, tabbar.lua): each
-- line goes to every tab that shows its kind, and the frame draws the tab shown. frame.history keeps every line of the
-- session, whatever the tabs show.
--
-- s6-interface-5x (round 12, separation step 3): what every interface's chat uses is the game layer's
-- (core/game/chat.lua, TK.Game.Chat: the say modes and the menu's rows, Back to Talk, the typing area's rule, the offline
-- line's logic, the chat and scroll keys, the lines as TK_CHAT_LINE); this frame draws Modern's log and bar with it and
-- provides its line, its log and its prompt host there.
--
-- s6-ui-core (round 85): the XML twin's scripts; the frame, its bar, the chat-mode menu and the message pane are
-- main.xml's (core/xml.md).

local C = TK.GetComponent("chatframe")
local H = __tk
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local Chat = TK.Chat -- s6-modular-g round 15: the chat's colours (core/chat.lua)
local T = require("interfaces.modern.panels.chatframe.tabs")
local B = require("interfaces.modern.panels.chatframe.tabbar")
require("interfaces.modern.panels.chatframe.terminal") -- s6-play-modes (round 4): the Terminal tab; s6-ui-core (round 52): Modern's view of TK.Terminal
local Term = TK.Terminal -- s6-ui-core (round 52): the Terminal's shared part (core/terminal.lua)
-- C.tabs is the component's settings tabs (Component:StandardSettings): these have names of their own.
C.chatTabs, C.tabStrip = T, B -- s6-ui-core (round 52): C.terminal, never read, dropped (s6-optimize's chat review, H10)

local G = TK.Game.Chat -- s6-interface-5x (round 12, step 3): the chat's game layer

-- the scripts main.xml names, and its build (its templates: the menu, the message pane)
local scripts = {}
local ui

local function live() return H:IsLiveInput() end

-- ----- the log -----

--- Adds a line: its text, its colour and its outline's (r, g, b, 0-1; no outline when nil). A new line brings the log
--- back to the bottom, unless Shift is held, which keeps the lines in view (AddIncomingMessage 0x0047F370).
--- show (s6-ui-core, round 29: Astra's review of round 27): the newest line is shown even with Shift held, for a notice
--- the player must see (the screenshot's, whose BMP key is Shift+Scroll Lock). Without it, Shift keeps the view where it
--- is, as 4a's ChattingPane::AddIncomingMessage does.
--- kind (s6-ui-chat, the tabs): the line's message kind (tabs.lua's T.KINDS), which decides the tabs it shows in; the
--- client's own lines (no kind) are System's.
function C:AddLine(text, rgb, outline, show, kind)
    local entry = { text = text, rgb = rgb or Chat.colours.say, outline = outline, kind = T.KIND[kind] and kind or "system" }
    T:Add(entry, IsShiftKeyDown() and not show)
    -- s6-interface-5x (round 13's hotfix, a marked edit): the game screen's lines given at a late start are drawn once
    -- after them (TK_CHAT_REPLAYED below)
    if G.replaying then return end
    self:Layout()
    B:Refresh()
end

--- Scrolls the shown tab's log n lines back (older), or forward for a negative n, down to the newest (the wheel; the
--- scroll keys through the game layer's TK.Game.Chat.ProvideLog while this frame shows).
function C:Scroll(n)
    local tab = T:Current()
    tab.offset = math.max(0, math.min(tab.offset + n, #tab.lines - 1))
    self:Layout()
end

--- A page back (dir 1) or forward (-1): the lines the log shows, less one (ChattingPane::GetPageSize 0x0047F600).
function C:Page(dir)
    self:Scroll(dir * math.max(1, self.frame.shown - 1))
end

--- The original's message pane (0x58): a line of text at the top of the screen until the server closes it. s6-interface-5x
--- (round 12, build 46; the owner: another interface's panels that are off do nothing): only while the chat frame is on,
--- so not in 7.x's and 5.x's profiles, where it is off (7.x's own banner is separation gap G4). Drawing only.
local banner
local function showBanner(text)
    if C:DB().enabled == false then return end
    banner = banner or ui:New("Banner", UIParent)
    banner.text:SetText(text)
    banner:SetShown(text ~= "")
end

--- A line of the game layer's (TK_CHAT_LINE: its colours as 4a's chat pane gives them), in the tabs that show its kind;
--- the server's message pane (0x58) at the top of the screen.
local function onLine(_, entry, show)
    if entry.channel == "banner" then
        showBanner(entry.text)
        return
    end
    -- s6-ui-chat: the tabs that show it (the client's own lines, with no channel, are System's)
    local kind = entry.channel and T.Classify(entry.channel, entry.speaker, entry.raw)
    C:AddLine(entry.text, entry.rgb, entry.outline, show, kind)
end

-- ----- the chat bar -----

local backToTalk = G.BackToTalk

--- The chat-mode button's text: the say mode's; s6-play-modes (round 4): "Terminal" while the Terminal tab is shown
--- live, whose line the keys then open.
function C:ModeText()
    if live() and T:Current().terminal then return "Terminal" end
    return G.MODES[G.SayMode() + 1] or "Talk"
end

function C:ShowBar()
    local f = self.frame
    if not f then return end
    f.modeButton:SetText(self:ModeText())
    local on = backToTalk()
    W.Color(f.talk.label, on and W.gold or W.grey)
end

--- The chat-mode menu (ChattingVarietySelectPane, a row acts on its release: ChattingPane.cpp:912-959): Talk, Shout,
--- Whisper, Group and Clan set the mode and open its line (the rules' chat:mode), -Color- opens the colour dialog. Wire:
--- each row carries the game layer's action for it (TK.Game.Chat.MenuAction, 4a's row dispatch 0x004811C0) and runs it on
--- the click's release (MenuChosen); changing either changes the chat packets that follow.
function C:BuildMenu()
    local m = ui:New("ModeMenu", UIParent)
    TK.Escape:AddWindow(m)
    -- A press anywhere else closes it (the press then goes on), as the original's (ChattingPane.cpp:900-906). Wire: 4a's
    -- ChattingVarietySelectPane::HandlePointerOrMouseEvent (0x004811C0) lets a press outside the menu go on (it returns
    -- false), so this only watches: taking the press would change what the server sees. Modern closes the menu on any
    -- button's press; 4a's, and 7.x's (panels/saymode), on a left press.
    TK.On("GLOBAL_MOUSE_DOWN", function()
        if m:IsShown() and not TK.Util.MouseWithin(m, self.frame.modeButton) then m:Hide() end
    end)
    self.menu = m
end

--- Live: the logic's text line (the chat's or a prompt's), drawn with its caret in the typing area, and the say mode on
--- the chat-mode button. A press on the typing area opens the say mode's line (the rules' chat:current) only while no
--- line or prompt is open, as the original's (the game layer's typing rule, TK.Game.Chat.UpdateTyping: wire).
function C:DrawLine()
    local f = self.frame
    -- s6-modular-g (interfaces, round 14): another interface's chat bar (7.x's) draws the line and takes the presses while
    -- it shows, so this frame leaves its own bar out meanwhile (drawing only; round 12: by the game layer's line providers)
    local elsewhere = G.OtherBarShown("chatframe")
    if f.bar:IsShown() == elsewhere then f.bar:SetShown(not elsewhere) end
    if not live() then return end
    local owner = H:GetLineOwner()
    if owner == "Chat" or (owner == "Prompt" and H:GetLineKind() == "Text") then
        local line = H:GetLine()
        if line.Version ~= f.line.version then
            f.line.version = line.Version
            f.line:SetText(line.Label .. TK.Util.WithCaret(line.Text, line.SelectionEnd))
            if self.menu then self.menu:Hide() end
        end
    elseif f.line.version ~= -1 then
        f.line.version = -1
        f.line:SetText("")
    end
    G.UpdateTyping(f.typing)
    local mode = self:ModeText()
    if mode ~= f.shownMode then
        f.shownMode = mode
        f.modeButton:SetText(mode)
    end
end

-- ----- offline: the game layer's line, on this bar while it shows -----

-- The offline line is the game layer's (TK.Game.Chat: OpenOffline, CloseOffline), drawn on the bar that shows (this
-- frame's box and prompt: OnEnable's ProvideLine).

-- ----- the tabs (s6-ui-chat): what the tab strip asks, saved per character -----

local stores = {}

--- The character's chat tabs, written half a second after the last change (TK.NewStore's rules).
local function store()
    local name, ref = TK.Characters.name, TK.Characters.ref
    if not ref then return nil end
    local key = ref:lower()   -- s6-layout round 4: the character on its server
    if not stores[key] then
        stores[key] = TK.NewStore("The chat tabs of " .. name, function(d) return H:CharacterSave(ref, "chat", d) end)
        table.insert(TK.Stores, stores[key])
    end
    return stores[key]
end

--- After any change to the tabs: saved, the strip and the log drawn again.
function C:TabsChanged()
    local s = store()
    if s then
        s.data = T:Saved()
        s:MarkDirty()
    end
    B:Refresh()
    B:SettingsFollow()
    self:Layout()
    Term.Follow() -- s6-play-modes: the tab shown may have changed
end

--- The character's tabs, at its entry into the world (its saved layout, or the default); each tab's lines from the
--- session's so far (the login's lines come before the world).
function C:LoadTabs()
    local name, ref = TK.Characters.name, TK.Characters.ref
    local data = ref and H:CharacterLoad(ref, "chat") or nil
    if not T:Load(data) then H:LogWarning("chat tabs of " .. tostring(name) .. ": not usable, the default tabs instead") end
    self.tabsOf = ref -- s6-play-modes (round 6): whose tabs these are (the frame's OnShow makes a GM only of their character)
    B:CloseSettings()
    B:Refresh()
    self:Layout()
    -- s6-play-modes: the rules start with General shown; on this client's own server the Terminal's character is a GM
    Term.Follow()
    Term.MakeGM()
end

function C:SelectTab(i)
    if T:Select(i) then
        B:Refresh()
        self:Layout()
        Term.Follow() -- s6-play-modes
    end
end

function C:CreateTab(name)
    if T:Create(name) then self:TabsChanged() end
end

--- s6-play-modes (round 4): the Terminal tab (terminal.lua), added from a tab's menu.
function C:AddTerminal()
    if T:AddTerminal() then
        self:TabsChanged()
        Term.MakeGM()
    end
end

function C:CloseTab(i)
    if T:Close(i) then
        B:CloseSettings()
        self:TabsChanged()
    end
end

function C:RenameTab(i, name)
    if T:Rename(i, name) then self:TabsChanged() end
end

function C:MoveTab(i, to)
    if T:Move(i, to) then
        B:CloseSettings()
        self:TabsChanged()
    end
end

function C:LockTab(i, on)
    if T.tabs[i] then
        T.tabs[i].locked = on and true or false
        self:TabsChanged()
    end
end

function C:SetTabFontSize(i, size)
    if T.tabs[i] then
        T.tabs[i].fontSize = size
        self:TabsChanged()
    end
end

function C:SetTabShows(i, kind, on)
    if T:SetShows(i, kind, on) then self:TabsChanged() end
end

--- Reset Chat Windows: the default tabs, General showing every kind.
function C:ResetTabs()
    T:Reset()
    B:CloseSettings()
    self:TabsChanged()
end

-- ----- the frame -----

-- ----- main.xml's scripts -----

function scripts.Own(f) C:Own(f) end

function scripts.HudPanel(f) W.HudPanel(f, C) end

-- s6-ui-chat: the tab strip along the top (tabbar.lua); every line of the session stays in frame.history
function scripts.TabStrip(f)
    B:Build(f)
    f.history, f.lines, f.shown = T.all, {}, 1
end

function scripts.Wheel(_, delta) C:Scroll(delta > 0 and 1 or -1) end

function scripts.Newest() C:Scroll(-T:Current().offset) end

function scripts.BackToTalk() G.SetBackToTalk(not backToTalk()) end

function scripts.TalkTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Back to Talk: " .. (backToTalk() and "on" or "off"), 1, 1, 1)
    GameTooltip:AddLine("On, ' and the typing area open Talk's line after any line; off, the last mode's.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function scripts.Untip() GameTooltip:Hide() end

function scripts.ToggleMenu()
    local m = C.menu
    m:SetShown(not m:IsShown())
end

-- Wire: the typing area's action is the rules' chat:current (the say mode's line, ChattingPane.cpp:1244-1257), which
-- its press runs; changing it changes what the server sees.
function scripts.TypingAction(typing) TK.Actions:SetTable(typing, { kind = "chat:current" }) end

-- The left press opens the line, so keys typed before the release are its: live, the area's action rides the press's
-- record. Wire: the game layer's typing rule (TK.Game.Chat.TypingPress); changing it changes what the server sees.
function scripts.TypingPress(typing, button)
    if button == "LeftButton" then G.TypingPress(typing) end
end

function scripts.BarParts(bar)
    local f, typing = bar:GetParent(), bar.typing
    f.bar, f.talk, f.modeButton, f.typing = bar, bar.talk, bar.modeButton, typing
    f.line, f.prompt, f.input = typing.line, typing.prompt, typing.input
end

function scripts.Provide(f)
    local bar = f.bar
    G.ProvideLine("chatframe", { shown = function() return bar:IsVisible() end, box = f.input,
                                 prompt = function(text) f.prompt:SetText(text) end })
    -- the log the scroll keys move while this frame shows, and a host of the rules' Text prompt (this bar draws it)
    G.ProvideLog("chatframe", { shown = function() return f:IsVisible() end, scroll = function(n) C:Scroll(n) end,
                                page = function(dir) C:Page(dir) end })
    TK.Game.Prompts.ProvideHost("chatframe", function() return f:IsVisible() end)
end

function scripts.Draw() C:DrawLine() end

function scripts.Shown()
    Term.Follow()
    if C.tabsOf ~= nil and C.tabsOf == TK.Characters.ref then Term.MakeGM() end
end

function scripts.Hidden() Term.Follow() end

-- the menu: a row a mode, in the game layer's order (TK.Game.Chat.MENU)
local making -- the index of the menu row being made (scripts.MenuRows), for its scripts

function scripts.FitMenu(m) m:SetSize(ui.MENU.width, #G.MENU * ui.MENU.row + 8) end

function scripts.MenuRows(m, build)
    for i = 1, #G.MENU do
        making = i
        m.rows[i] = build:New("MenuRow", m)
    end
    making = nil
end

function scripts.MenuRow(row)
    local m, y = row:GetParent(), -4 - (making - 1) * ui.MENU.row
    row:SetPoint("TOPLEFT", m, "TOPLEFT", 4, y)
    row:SetPoint("TOPRIGHT", m, "TOPRIGHT", -4, y)
    row.index, row.caption = making, G.MENU[making]
end

-- Wire: the row carries the game layer's action for its mode (TK.Game.Chat.MenuAction, 4a's row dispatch 0x004811C0);
-- changing it changes the chat packets that follow.
function scripts.MenuRowAction(row) TK.Actions:SetTable(row, G.MenuAction(row.index)) end

-- Wire: the row's action runs on the click's release (TK.Game.Chat.MenuChosen, 4a's row dispatch 0x004811C0); changing
-- it changes the chat packets that follow.
function scripts.MenuRowClick(row)
    row:GetParent():Hide()
    G.MenuChosen(row.index)
end

-- the message pane goes when the player leaves the world
function scripts.BannerLeaves(b) TK.On("PLAYER_LEAVING_WORLD", function() b:Hide() end) end

function C:OnEnable()
    ui = TK.Xml.Load("main.xml", { scripts = scripts, elements = require("interfaces.modern.elements") })
    local f = ui.frame
    self.frame = f
    B:Refresh()
    self:BuildMenu()
    -- every line (the session's, the rules' notices, the client's own: the game layer's TK_CHAT_LINE), and the bar drawn
    -- again when Back to Talk or the offline line changes
    TK.On("TK_CHAT_LINE", onLine)
    -- s6-interface-5x (round 13's hotfix, a marked edit): after the game screen's lines given at a late start
    -- (TK.Game.Chat.Replay), drawn once; old whispers alert no tab, as the tabs loaded at a world entry
    TK.On("TK_CHAT_REPLAYED", function()
        for _, tab in ipairs(T.tabs or {}) do tab.alert = false end
        C:Layout()
        B:Refresh()
    end)
    TK.On("TK_CHAT_SETTINGS", function() C:ShowBar() end)
    -- s6-ui-font: below UI scale 1 the classic font is drawn one to one, so its lines' height changes with the scale.
    TK.On("UI_SCALE_CHANGED", function() C:Layout() end)
    -- s6-rules-dialogs (round 17): an online game screen starts at the login's accepted 02, as 4a builds its panes there
    -- (InitializeMainUiGraph): the lines after it, before the world entry (live's login notices, the equipment's lines),
    -- are the new screen's, so the log is cleared then and not again at the entry.
    TK.On("TK_SESSION_STATE", function(_, state)
        if state ~= "Accepted" then return end
        T:Clear()
        C:Layout()
    end)
    TK.On("PLAYER_ENTERING_WORLD", function()
        -- Each world entry is a new game screen, as the original's: the last session's lines, or the mock world's, go
        -- (head note 35); the offline line's mode is Talk again and the mock world says so (the game layer's).
        if not H:IsOnline() then T:Clear() end -- s6-rules-dialogs (round 17): online, at the 02
        C:LoadTabs() -- s6-ui-chat: the character's tabs
        C:ShowBar()
    end)
    TK.Visibility:Attach(f, function() return self:DB() end)
    -- s6-ui-core (round 28): the original's height handle (ChattingModifyHeightPane, C-12) is edit mode's grip here, as
    -- the world view's: it sets the Width and Height settings, within their ranges.
    TK.EditMode:Register(f, "chatframe", "Chat Frame", C.defaultPosition, "chatframe", nil, {
        minWidth = 200,
        minHeight = 80,
        set = function(w, h)
            local db = self:DB()
            db.width, db.height = math.min(w, 900), math.min(h, 600)
            self:ApplySettings()
            TK.DB:MarkDirty()
        end,
    })
    -- (Back to Talk on at every start, Config.cpp:1347-1349, is the game layer's since round 12: core/game/chat.lua.)
    self:ShowBar()
end

-- GrafPort::DrawOutlinedText (0x004BAFA0): the text in the outline colour a pixel left, right, up and down, then the text.
local OUTLINE = { { -1, 0 }, { 1, 0 }, { 0, 1 }, { 0, -1 } }

local function lineLabel(f, layer)
    local fs = f:CreateFontString(nil, layer)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs
end

--- size: the tab's own font size (s6-ui-chat), in the open font; 0 follows the chat's settings.
local function setLine(f, fs, db, size, text, rgb, x, y)
    if size > 0 then fs:SetFont("", size, "")
    elseif db.classicFont then fs:SetFont("classic", 12, "") else fs:SetFont("", db.fontSize, "") end
    fs:SetWidth(db.width - 16)
    fs:SetText(text)
    fs:SetTextColor(rgb[1], rgb[2], rgb[3], 1)
    fs.rgb = rgb
    fs:ClearAllPoints()
    fs:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, y)
end

--- Draws the shown tab's lines that fit, from the bottom up, the newest shown line its offset lines back.
function C:Layout()
    local db, f = self:DB(), self.frame
    if not f then return end
    local tab = T:Current()
    local history, size = tab.lines, tab.fontSize
    local y, used, shown = 6, 0, 0
    for i = #history - tab.offset, 1, -1 do
        used = used + 1
        local fs = f.lines[used]
        if not fs then
            fs = lineLabel(f, "OVERLAY")
            fs.outline = {}
            for k = 1, #OUTLINE do fs.outline[k] = lineLabel(f, "ARTWORK") end
            f.lines[used] = fs
        end
        local entry = history[i]
        setLine(f, fs, db, size, entry.text, entry.rgb, 8, y)
        for k, o in ipairs(fs.outline) do
            if entry.outline then setLine(f, o, db, size, entry.text, entry.outline, 8 + OUTLINE[k][1], y + OUTLINE[k][2]) end
        end
        y = y + fs:GetStringHeight() + 2
        local fits = y <= db.height
        fs:SetShown(fits)
        for _, o in ipairs(fs.outline) do o:SetShown(fits and entry.outline ~= nil) end
        if not fits then break end
        shown = shown + 1
    end
    for i = used + 1, #f.lines do
        f.lines[i]:Hide()
        for _, o in ipairs(f.lines[i].outline) do o:Hide() end
    end
    f.shown = math.max(1, shown)
    f.more:SetShown(tab.offset > 0)
end

function C:ApplySettings()
    local db, f = self:DB(), self.frame
    f:SetSize(db.width, db.height)
    -- s6-ui-font: the scale first; below one pixel per font pixel the classic lines' height follows it (review r1, P2).
    TK.Visibility:Apply(f)
    self:Layout()
    if banner and db.enabled == false then banner:Hide() end -- s6-interface-5x (round 12): the banner goes with it
end

-- (The chat keys and the log's scroll keys are the game layer's since round 12: core/game/chat.lua.)
