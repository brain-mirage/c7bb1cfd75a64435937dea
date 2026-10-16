-- s6-interface-5x (round 12, separation step 3; docs/development/interface-separation.md, section 5.7): the chat's game
-- layer, every interface's: the say modes and the chat-mode menu's rows, Back to Talk, the typing area's rule, the
-- offline line's logic (the mock world: the keys and the menu open it, Enter runs what it holds), the chat keys and the
-- log's scroll keys. Moved from Modern's chat frame (interfaces/modern/panels/chatframe), which 7.x's chat bar, log and
-- say-mode button reached into before (its barElsewhere, typingElsewhere, lineAdded and logElsewhere hooks).
--
-- Who draws: an interface's chat bar provides its offline line (ProvideLine: its box and its prompt; the line opens on
-- the bar that shows), its log provides its scroll (ProvideLog: the keys go to the log that shows), the latest provided
-- asked first (the design's R3 and R7). Every line of the chat comes to all as TK_CHAT_LINE (built here, coloured by
-- core/chat.lua).
--
-- Wire: live, the lines, their keys and what Enter sends are the chat rules' (TK.Core.Rules.Chat.ChatRules: 0E, 19);
-- this hands them the presses in their input (the typing area's chat:current, the menu's chat:mode, the keys' actions)
-- and Back to Talk's setting. Each piece below says what of 4a it keeps.

local H = __tk

TK.Game = TK.Game or {}
local G = { lineProviders = {}, logs = {}, offlineMode = 0 }
TK.Game.Chat = G

local function live() return H:IsLiveInput() end

-- ----- the say modes, the menu and Back to Talk -----

--- The say modes as the chat-mode button names them (ChattingVarietyPane::OnPaint 0x00480E80), and their lines' prompts
--- as the rules open them (ChatRules: OpenSay, OpenShout, the "To" line, OpenGroup, OpenClan).
G.MODES = { "Talk", "Shout", "Whisper", "Group", "Clan" }
G.PROMPTS = { "> ", "! ", "To ", "Group => ", "Clan => " }

--- The chat-mode menu's rows (ChattingVarietySelectPane; a row acts on its release: ChattingPane.cpp:912-959).
G.MENU = { "Talk", "Shout", "Whisper", "Group", "Clan", "-Color-" }

--- Back to Talk (the chat bar's button 0, ChattingHandlePane field_111, Config::m_chatHandleLeftToggle), as settings.toml
--- keeps it.
function G.BackToTalk() return H:ClientSettingBool("chat", "handle_left") end

--- Back to Talk turned over on its button's release (ChattingPane.cpp:1273-1276): kept in settings.toml and handed to
--- the rules in the click's place (ApplyChat: two flags posted to the logic, nothing sent); every chat bar draws it again
--- (TK_CHAT_SETTINGS). Wire: the rules' Back to Talk decides which mode the next line opens in, so which 0E goes.
function G.SetBackToTalk(on)
    H:ClientSettingSetBool("chat", "handle_left", on and true or false)
    H:ClientSettingsSave()
    H:ApplyChat()
    TK.FireEvent("TK_CHAT_SETTINGS")
end

--- ChattingHandlePane's two presentation settings. Shared game data; each interface supplies its own controls.
function G.BackdropMode() return H:ClientSettingInt("chat", "mode") end
function G.LogEnabled() return H:ClientSettingBool("chat", "secondary") end

--- 4a ChattingHandlePane::HandlePointerOrMouseEvent (0x00481D60), region 2's release: 0, 1, 2, 0; no packet.
--- Presentation only, silent as in 4a. The caller retains the matching press/release condition.
function G.CycleBackdrop()
    H:ClientSettingSetInt("chat", "mode", (G.BackdropMode() + 1) % 3)
    H:ClientSettingsSave()
    TK.FireEvent("TK_CHAT_SETTINGS")
end

--- 4a ChattingHandlePane::HandlePointerOrMouseEvent (0x00481D60), region 3's release: the log/backdrop/handle switch,
--- no packet. Only presentation changes; the typing bar stays active. The caller retains 4a's release condition.
function G.ToggleLog()
    H:ClientSettingSetBool("chat", "secondary", not G.LogEnabled())
    H:ClientSettingsSave()
    TK.FireEvent("TK_CHAT_SETTINGS")
end

--- The say mode the chat-mode buttons show (0-4): the rules' live, the offline line's own offline.
function G.SayMode()
    if live() then return H:GetSayMode() end
    return G.offlineMode or 0
end

--- s6-interface-7x: row i's action, for every look's menu (Modern's chat frame's, 7.x's say-mode menu). Wire (Astra's
--- review of round 1): this is 4a's row dispatch, ChattingVarietySelectPane::HandlePointerOrMouseEvent (0x004811C0): row
--- i is say mode i - 1 (Talk 0, Shout 1, Whisper 2, Group 3, Clan 4; the rules' ChatRules.MenuRow: chat:mode sets
--- UserPane::m_currentSayMode and opens the mode's line), which opens the line that decides how the typed text goes out
--- (0E with its mode byte for Talk and Shout, 19 for the whisper's, the group's and the clan's lines); -Color- opens the
--- ChattingColorPane dialog. Nothing is sent by a choice. Changing the mapping changes the chat packets that follow.
function G.MenuAction(i)
    return i <= 5 and { kind = "chat:mode", amount = i - 1 } or { kind = "dialog:open", text = "ChattingColorPane" }
end

--- A row's release: live, the action frozen for the release runs (MenuAction's); offline, a mode's row opens its line.
--- Wire: as MenuAction.
function G.MenuChosen(i)
    if live() then TK.Actions:RunFrozen() elseif i <= 5 then G.OpenOffline(i - 1) end
end

-- ----- the typing area -----

--- The typing area's action as the line is now: the rules' chat:current (the say mode's line, or Talk's with Back to
--- Talk: UserPane::OpenInputPaneForCurrentSayMode) only while no line or prompt is open (m_activeLineInputPane,
--- ChattingPane.cpp:1253-1257). Called from a bar's OnUpdate and at its press. Wire: which press opens the line.
function G.UpdateTyping(area)
    local idle = H:GetLineOwner() == "None"
    if idle == area.tkIdle then return end
    area.tkIdle = idle
    TK.Actions:SetTable(area, idle and { kind = "chat:current" } or nil)
end

--- A left press on a typing area (ChattingPane.cpp:1244-1257: the press opens the line, so keys typed before the release
--- are its). Live: the area's action as the line is at this press (s6-ui-core round 32: a press in the frame whose Esc
--- closed the line opens it again, as 4a's in the input's order), run on the press's record. Offline: the say mode's
--- line (Talk's with Back to Talk), unless one is open. Wire: as UpdateTyping.
function G.TypingPress(area)
    if live() then
        G.UpdateTyping(area)
        TK.Actions:RunFrame(area)
    elseif not G.offline then
        G.OpenOffline(G.BackToTalk() and 0 or (G.offlineMode or 0))
    end
end

-- ----- offline: the line of the bar that shows -----

--- An interface's chat bar's offline line, under its panel: line.shown() (its bar shows now), line.box (its edit box,
--- which this drives: shown, filled, focused, its keys), line.prompt(text) (draws the line's prompt), line.bar (true for
--- a chat bar with the original's buttons, which stands in for Modern's: OtherBarShown). The latest provided asks first. The original's lines hold at most 80 characters (plan 5.7, chat).
function G.ProvideLine(panelId, line)
    table.insert(G.lineProviders, 1, TK.Mark({ panel = panelId, line = line }))
    local box = line.box
    box:SetMaxLetters(80)
    box:SetScript("OnEnterPressed", function() G.OfflineEnter() end)
    box:SetScript("OnTextChanged", function() G.UpdateAction() end)
    box:SetScript("OnEscapePressed", function() G.CloseOffline(not (G.offline and G.offline.mode == "line")) end)
    box:Hide()
end

--- The offline line of the bar that shows, or nil.
local function lineShown()
    for _, e in ipairs(G.lineProviders) do
        if e.line.shown() then return e.line end
    end
end

--- Whether another panel's chat bar (line.bar) than panelId's shows (Modern's chat frame leaves its own bar out then).
function G.OtherBarShown(panelId)
    for _, e in ipairs(G.lineProviders) do
        if e.panel ~= panelId and e.line.bar and e.line.shown() then return true end
    end
    return false
end

--- Offline (the mock world): the line, opened as the rules open theirs (mode 0-4, or "line" for Alt+c's, which stays
--- open), with text already in it, on the bar that shows; none shows, none opens. Nothing is sent offline.
function G.OpenOffline(mode, text)
    local line = lineShown()
    if not line then return end
    if G.offline and G.offline.line ~= line then G.CloseOffline(false) end
    if mode ~= "line" then G.offlineMode = mode end
    G.offline = { mode = mode, line = line }
    line.prompt(mode == "line" and ">" or G.PROMPTS[mode + 1])
    line.box:Show()
    line.box:SetText(text or "")
    line.box:SetFocus()
    G.UpdateAction()
    TK.FireEvent("TK_CHAT_SETTINGS")
end

--- The offline line's action as typed, attached to its box so its Enter runs what it held (plan 5.9).
function G.UpdateAction()
    local o = G.offline
    if not o then return end
    local text = o.line.box:GetText()
    local a
    if text ~= "" then
        local m = o.mode
        if m == "line" or m == 0 then a = { kind = "say", text = text }
        elseif m == 1 then a = { kind = "shout", text = text }
        elseif m == 2 then a = o.to and { kind = "whisper", text = o.to .. "\n" .. text } or nil
        elseif m == 3 then a = { kind = "whisper", text = "!!\n" .. text }
        elseif m == 4 then a = { kind = "whisper", text = "!\n" .. text } end
    end
    TK.Actions:SetTable(o.line.box, a)
end

--- The offline line's Enter: the "To" line names the whisper's player and opens its message line; any other line runs
--- its action and closes, but Alt+c's, which only empties.
function G.OfflineEnter()
    local o = G.offline
    if not o then return end
    local box = o.line.box
    local text = box:GetText()
    -- The Enter that sent the line must not open the line again once the box has let go of the keyboard.
    G.sentFrame = H:GetFrameNumber()
    if o.mode == 2 and not o.to then
        if text == "" then return G.CloseOffline(true) end
        o.to = text
        o.line.prompt("To " .. text .. " : ")
        box:SetText("")
        return
    end
    if text ~= "" then TK.Actions:RunFrozen() end
    if o.mode == "line" then
        box:SetText("")
        return
    end
    G.CloseOffline(true)
end

--- Closes the offline line; ended: Back to Talk acts (not on Alt+c's line, whose Escape ends no LineInputPane).
function G.CloseOffline(ended)
    local o = G.offline
    if not o then return end
    G.offline = nil
    local box = o.line.box
    box:SetText("")
    box:ClearFocus()
    box:Hide()
    o.line.prompt("")
    if ended and o.mode ~= "line" and G.BackToTalk() then G.offlineMode = 0 end
    TK.FireEvent("TK_CHAT_SETTINGS")
end

-- Escape closes the offline line even before its box has the keyboard.
TK.Escape:AddCancel("chatline", 5, function()
    if not G.offline then return false end
    G.CloseOffline(G.offline.mode ~= "line")
    return true
end)

-- Each world entry is a new game screen, as the original's: the offline line's mode is Talk again (the UserPane's
-- constructor).
TK.On("PLAYER_ENTERING_WORLD", function() G.offlineMode = 0 end)

-- ----- the lines -----

local Chat = TK.Chat -- the chat's colours (core/chat.lua)
local BLACK = { 0, 0, 0 }

--- Every line for the chat's logs, one TK_CHAT_LINE (entry, show) each: entry.text, entry.rgb and entry.outline (0-1
--- colours; no outline when nil) as 4a's chat pane colours it, entry.channel and entry.speaker as the session gave them
--- (entry.raw, the text as it came), so a log may sort or leave out lines by them; show: the newest line is shown even
--- with Shift held (Modern's chat frame's AddLine). Built here once from the session's lines (TK_CHAT_MESSAGE), the
--- rules' notices (TK_RULES_MESSAGE, channel "notice") and the client's own (TK_CLIENT_MESSAGE, no channel). The
--- server's message pane (0x58) comes as channel "banner"; its popups (0x0A kind 8) open a notice box here instead.
--- Drawing only: nothing is sent.
local function fire(entry, show) TK.FireEvent("TK_CHAT_LINE", entry, show) end

-- s6-interface-5x (round 13's hotfix, Astra's self-review; interface-separation.md 5.16, point 6): the game screen's lines
-- so far, oldest first, as { event, args, entry }: the event the session, the rules or the client fired (TK_CHAT_MESSAGE,
-- TK_RULES_MESSAGE, TK_CLIENT_MESSAGE; none for the mock world's line) with its arguments, and the line made of it
-- (TK_CHAT_LINE's entry, or none), at most 1000 as 4a's chat pane keeps (List(4, 1000)). Each interface's log takes its
-- lines at one of those two layers, so a log started later (an interface switched to, a chat panel turned on) is given
-- them (G.Replay) and shows the conversation so far, as one that ran all along. Cleared with the logs, at a new game
-- screen. Drawing only: nothing is sent.
local KEEP = 1000
G.history = {}

local function remember(event, args, entry, to)
    local h = G.history
    h[#h + 1] = { event = event, args = args, entry = entry, to = to }
    if #h > KEEP then table.remove(h, 1) end
end

--- A line a log shows by its own way, not by the events above (the Terminal's: core/terminal.lua), kept in order with
--- them: to(owner, panel) shows it again in what that owner made, at a late start (G.Replay), without running again what
--- made it (a command's handler). Astra's self-review 13-2.
function G.Remember(to) remember(nil, nil, nil, to) end

-- a new game screen, as the logs clear theirs: online at the login's accepted 02 (InitializeMainUiGraph), offline at each
-- world entry
TK.On("TK_SESSION_STATE", function(_, state) if state == "Accepted" then G.history = {} end end)
TK.On("PLAYER_ENTERING_WORLD", function() if not H:IsOnline() then G.history = {} end end)

local REPLAYED = { "TK_CHAT_MESSAGE", "TK_RULES_MESSAGE", "TK_CLIENT_MESSAGE", "TK_CHAT_LINE" }

--- The game screen's lines given to a log started late (TK.Components:Start, after the start's events), to what that
--- owner (a component's name; panel: only what was made for that panel) listens with alone, in order: each event as it
--- came, each line as TK_CHAT_LINE (shown at the newest), each line kept with G.Remember by its own function, then
--- TK_CHAT_REPLAYED, at which a log that kept them without drawing while G.replaying draws once. Nothing for an owner that
--- listens to none of them. Drawing only.
function G.Replay(owner, panel)
    if #G.history == 0 then return end
    local listens = false
    for _, event in ipairs(REPLAYED) do listens = listens or TK.Listens(owner, panel, event) end
    if not listens then return end
    G.replaying = true
    for _, r in ipairs(G.history) do
        if r.event then TK.DeliverTo(owner, panel, r.event, table.unpack(r.args, 1, r.args.n)) end
        if r.entry then TK.DeliverTo(owner, panel, "TK_CHAT_LINE", r.entry, true) end
        if r.to then r.to(owner, panel) end
    end
    G.replaying = false
    TK.DeliverTo(owner, panel, "TK_CHAT_REPLAYED")
end

TK.On("TK_CHAT_MESSAGE", function(_, channel, text, colour, back, speaker)
    if channel == "popup" then
        TK.Popup(text, "Message")
        return
    end
    local entry = { channel = channel, speaker = speaker, raw = text, text = text }
    if channel == "colored" then
        -- Every line of the original's chat pane is outlined (ColorStringChattingMessage::Draw 0x004836A0, style 0): in
        -- its pair's outline colour, or the packet's own for 0x0A kind 18 and 0x0D kind 4; black without the packs'
        -- palette. Outline 0, the outline grid's first swatch where the text grid has 15 (ChattingPane.cpp:1549-1564), is
        -- none.
        entry.rgb, entry.outline = Chat.Packed(colour) or Chat.colours.colored, Chat.Packed(back) or BLACK
    elseif channel ~= "banner" then
        entry.text = Chat.Rearrange(channel, text)
        local fg, outline = Chat:LineIndexes(channel, speaker)
        entry.rgb = fg and Chat:PaletteRGB(fg) or Chat.colours[channel] or Chat.colours.say
        entry.outline = fg and outline ~= 0 and (Chat:PaletteRGB(outline) or BLACK) or nil
    end
    remember("TK_CHAT_MESSAGE", table.pack(channel, text, colour, back, speaker), entry)
    fire(entry)
end)

-- s6-ui-core (round 33, for s6-rules-items): the rules' local system messages, in the order made, as 4a's
-- SystemMessagePane::AddColorStringMessage writes them (0x84 on 0x24: AddInventoryItemNotice, the arrows' line).
TK.On("TK_RULES_MESSAGE", function(_, text)
    local entry = { text = text, raw = text, channel = "notice", rgb = Chat:PaletteRGB(0x84) or Chat.colours.notice,
                    outline = Chat:PaletteRGB(0x24) or nil }
    remember("TK_RULES_MESSAGE", table.pack(text), entry)
    fire(entry)
end)

-- s6-interface-5x (Astra's review of its round 1): the client's own lines (the screenshot's notice, the Classic Commands
-- help, the options' notices); rgb and outline palette 0-1 colours or nil.
TK.On("TK_CLIENT_MESSAGE", function(_, text, rgb, outline, show)
    local entry = { text = text, raw = text, rgb = rgb or Chat.colours.say, outline = outline }
    remember("TK_CLIENT_MESSAGE", table.pack(text, rgb, outline, show), entry)
    fire(entry, show)
end)

-- Offline (the mock world), each world entry says so in the logs, after they have started again (in the next frame).
TK.On("PLAYER_ENTERING_WORLD", function()
    if H:IsOnline() then return end
    TK.Await(function() return true end, function()
        local entry = { text = "Offline: this is the local mock world, and nothing is sent anywhere.", rgb = Chat.colours.local_ }
        remember(nil, nil, entry)
        fire(entry)
    end)
end)

-- Back to Talk comes back on at every start in the original: Config reads it as any of ChatWindow's top two bytes, which
-- hold the line count (at least 4) too (Config.cpp:1347-1349, :1661-1663). s6-interface-5x (round 11, W11): and the rules
-- are told (ApplyChat: two flags posted to the logic, nothing sent). At a start no session exists yet, which reads the
-- file when it is made; after a UI reload in the world the session's rules still had the player's choice. Wire: the
-- rules' Back to Talk decides which mode the next line opens in, so which 0E goes; the UI and the rules must agree, as at
-- a fresh start in the world. Changing this changes what the server sees. (Modern's chat frame did this as it was
-- enabled, in every interface; round 12 moved it here, at the UI's start.)
TK.On("PLAYER_LOGIN", function()
    if H:ClientSettingInt("chat", "lines") ~= 0 and not G.BackToTalk() then
        H:ClientSettingSetBool("chat", "handle_left", true)
        H:ClientSettingsSave()
        H:ApplyChat()
        TK.FireEvent("TK_CHAT_SETTINGS")
    end
end)

-- ----- the logs' scroll keys -----

--- An interface's chat log, under its panel: log.shown() (it shows now), log.scroll(n) (n lines back, older; forward for
--- a negative n), log.page(dir) (a page back for 1, forward for -1). The scroll keys go to the log that shows, the latest
--- provided first, as 4a's one log takes them.
function G.ProvideLog(panelId, log)
    table.insert(G.logs, 1, TK.Mark({ panel = panelId, log = log }))
end

-- s6-interface-5x (round 13, the separation's step 11): a chat panel turned off takes its line and log with it
TK.OnWithdraw(function(name, panel)
    TK.DropOwned(G.lineProviders, name, panel)
    TK.DropOwned(G.logs, name, panel)
end)

--- The log that shows, or nil.
local function logShown()
    for _, e in ipairs(G.logs) do
        if e.log.shown() then return e.log end
    end
end

function G.Scroll(n)
    local log = logShown()
    if log then log.scroll(n) end
end

function G.Page(dir)
    local log = logShown()
    if log then log.page(dir) end
end

-- ----- the keys -----

-- The original's chat keys (UserPane::HandleKeyOrTextEvent 0x005A5BD0), each a binding with its action (plan D24) on the
-- original's key by default: live the rules open the original's lines (a key they pass on, as with the bow drawn,
-- opens nothing); offline the line of the bar that shows. The keypad's / types / as well (K-036). Wire: the commands'
-- action kinds go with their keys (names, actions and keys as Modern's chat frame registered them before round 12).
G.KEYS = {
    { "OPENCHAT", "Talk (Enter)", { kind = "say" }, "ENTER", function() G.OpenOffline(0) end },
    { "OPENCHATSLASH", "Talk with / (/)", { kind = "chat:slash" }, "/", function() G.OpenOffline(0, "/") end },
    { "CHATCURRENT", "The Say Mode's Line (')", { kind = "chat:current" }, "'",
        function() G.OpenOffline(G.BackToTalk() and 0 or (G.offlineMode or 0)) end },
    { "CHATSHOUT", "Shout (!)", { kind = "shout" }, "SHIFT-1", function() G.OpenOffline(1) end },
    { "CHATWHISPER", "Whisper (\")", { kind = "whisper" }, "SHIFT-'", function() G.OpenOffline(2) end },
    { "CHATLINE", "The Line That Stays Open (Alt+C)", { kind = "chat:line" }, "ALT-C", function() G.OpenOffline("line") end },
}
for _, k in ipairs(G.KEYS) do
    local offline = k[5]
    TK.Bindings:RegisterCommand(k[1], k[2], function()
        -- A new line replaces the open one, as a new LineInputPane does; the Enter that sent a line opens none.
        if live() or H:GetFrameNumber() == G.sentFrame then return end
        offline()
    end, k[3])
    TK.DB.defaultBindings[k[4]] = k[1]
end
TK.DB.defaultBindings["NUMPADDIVIDE"] = "OPENCHATSLASH"

-- The log's keys (ChattingPane::HandleKeyOrTextEvent 0x0047F6F0): live, the rules' chat log takes them before the game
-- (chat:scroll; nothing is sent) and the binding scrolls the log that shows on each key-down, repeats too. Wire: the
-- action kind keeps Shift with the walk keys from walking.
G.SCROLL_KEYS = {
    { "CHATSCROLLUP", "Chat: Scroll Up a Line", "SHIFT-UP", function() G.Scroll(1) end },
    { "CHATSCROLLDOWN", "Chat: Scroll Down a Line", "SHIFT-DOWN", function() G.Scroll(-1) end },
    { "CHATPAGEUP", "Chat: Scroll Up a Page", "SHIFT-PAGEUP", function() G.Page(1) end },
    { "CHATPAGEDOWN", "Chat: Scroll Down a Page", "SHIFT-PAGEDOWN", function() G.Page(-1) end },
}
for _, k in ipairs(G.SCROLL_KEYS) do
    TK.Bindings:RegisterCommand(k[1], k[2], k[4], { kind = "chat:scroll" })
    TK.DB.defaultBindings[k[3]] = k[1]
end

return G
