-- The login screen (plan 5.11, D23), the client's first state, and character creation.
--
-- Connect starts the chosen server's connection; only an accepted version handshake enables Login. The client
-- waits for a press at start, after a failure, and after a server/mode change. No connection retries start by themselves.
-- Wire: only the connect's trigger moved (owner, 2026-10-06). The session still matches TerminalPane::OnTimer
-- 0x0058B470 and HandlePacketEvent 0x0058B130, then LoginDialogPane::OnControlCommand 0x004FAD00: greeting, "baram",
-- version, replies and the original login wait. Changing this path changes what the server sees.
-- --login fills the fields and submits once Connect's handshake is accepted; it never presses Connect for the player.
--
-- The account name (at most 15 characters) and the password (at most 8) are handed to the session at once and the
-- password box is cleared; the session waits the original's 200-599 ms and sends the login. With "Save account
-- information" checked, the account is saved for the server once it is in the world, its password encrypted for
-- this Windows user (head note 29); a saved-account button fills the fields and submits only on an accepted connection.
-- The trash can asks before it deletes. The server's own messages are shown when it refuses.
--
-- Internet uses the saved server list; Local starts the configured server on this PC when Connect is pressed;
-- Dedicated shows its terminal and Start Server. The stable settings keys remain online/offline/server. Missing server
-- files leave Local and Dedicated visible but disabled. The local server's Allow Remote Users still controls hosting
-- while playing, and the mode is remembered. TK.Login:PlayOffline remains a test/preview mock world.
--
-- Log Out in the game is the original's exit to the menu (head note 28): 0B, and the session is back at its menu on
-- the same connection.
--
-- New Character sends the original's 0x02 (the account) and then 0x04 (the look) on the connection. Back or Escape
-- goes back; during a creation it ends the connection, so nothing more is sent, and the screen waits for Connect.
--
-- The original's other menu entries are the buttons at the bottom right (s6-ui-login): Change Password (its dialog
-- sends 0x26 on the connection), Story and History (picture books from the packs), and Quit (the connection is reset
-- and the client ends; nothing is sent). A server that refuses the client's version gets the original's alert, and
-- the menu stays on the connection, as the original's, its entries usable once the alert is acknowledged. The alerts
-- here are the original's AlertPane: modal, they take every key and click until OK, Enter or Escape.

local H = __tk
local W = TK.UI
local CrashNotice = require("core.crashnotice") -- s6-crash-reports seam: the last session's error

local L = {}
TK.Login = L

L.MAX_ACCOUNT, L.MAX_PASSWORD = 15, 8
-- A new account's password is read up to 15 characters (CreateUserDialogPane::SubmitCreateUser 0x0052ED80).
L.MAX_CREATE_PASSWORD = 15
L.MAX_SAVED = 8
-- The field a refused login gives the caret, by its 02's result (MainMenuPane.cpp:1279-1293); none for the others.
L.REFUSAL_FOCUS = { [14] = "account", [15] = "password", [16] = "account", [17] = "account", [18] = "account",
                    [20] = "account", [21] = "account" }

local screen, create  -- create: the New User dialog in use, ours or an interface's own login screen's (L:ShowCreate)
local ourCreate       -- ours, made once
local buildHost
local presentation -- an interface's own login screen in use (L:ApplyScreens), or nil for ours

--- The presentation's connect screen in a state (its contract's Terminal), where it draws one. Drawing only.
local function terminal(state)
    if presentation and presentation.Terminal then presentation.Terminal(state) end
end

-- s6-ui-core (round 32): the login screen's own end of a connection (Cancel, a change of server or mode, Quit...).
-- A connection lost after the greeting is the session's ConnectionClosedDialog's (L.lost: TK_SESSION_STATE below),
-- whose Leave closes the session itself; ending it here is not that Leave.
local function disconnect()
    L.lost = nil
    H:Disconnect()
end

-- s6-play-modes (round 10): the screen's block (plan D22 and D6: TK_LOGIN_BLOCKED's message; nil once lifted), kept by
-- the host as well (H:SetLoginBlock), so that a UI reload at the login screen (an interface switch) takes it back in L:Start.
-- Wire: a block lost across a reload let the screen connect again by itself, a connection the original never makes. After
-- an update request 4a exits (PatchPane 0x005470B0's AbortPatchingWithAlert 0x00547980, PatchPane2's FinishAndExit
-- 0x00548F80), at the ban mark it crashes (HandleWriteSystemMscfgDllPacket 0x00514250), and with a server list it stays
-- at its menu, sending nothing (MainMenuPane::HandlePacketEvent 0x004F6D80). Changing this changes what the server sees.
local function setBlocked(message)
    L.blocked = message
    H:SetLoginBlock(message or "")
end

-- The controls sit in one content frame of this size, centred and shrunk to fit small screens and high UI scales
-- (review R2.5); the background fills the screen.
local CONTENT_W, CONTENT_H = 680, 470

-- s6-login-scene (round 2): the pre-game screens' background, chosen here and nowhere else, so an interface overrides it in
-- one place (docs/development/interfaces.md, the `pregame` part). scene: the host's login scene, drawn behind the
-- UI (Modern's); picture: the texture the screens show where the scene is off or cannot run. An interface faithful to the
-- original would give the original's title picture (TK.Art.Image("TITLE.EPF")) and no scene. Read as the screens are
-- built.
L.background = { scene = true, picture = "tk:login-bg" }

local fullScreens = {}

--- The build's version as the pre-game screens' corner shows it (the owner, 2026-10-04: "my last one was release 39 it
--- should be version 0.39"): a release, a build named nextNN, is "Version 0.NN"; any other build (a worker's, a test's)
--- shows its own name, so it is never taken for a release; without one (the editor) "dev".
function L.VersionText(name)
    if name == nil or name == "" then return "dev" end
    local release = name:match("^next(%d+)$")
    return release and ("Version 0." .. release) or name
end

-- The scene while one of the full screens shows (one giving way to another keeps it: the host lets it go only at the
-- end of the frame), and each screen's picture wherever the scene does not show.
local function showBackground()
    local shown = false
    for _, f in ipairs(fullScreens) do shown = shown or f:IsShown() end
    -- s6-ui-login (round 10): held still with the machine setting Disable Login Page Animations (interface/settings.lua)
    H:SetLoginSceneStill(TK.Machine:Get() ~= nil and TK.Machine:Get().disableLoginAnimations == true)
    local scene = H:ShowLoginScene(shown and L.background.scene == true and presentation == nil)
    for _, f in ipairs(fullScreens) do f.background:SetShown(not scene) end
end

local function fullScreen(name, subtitle)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetFrameStrata("HIGH")
    f:SetAllPoints(UIParent)
    f:EnableMouse(true)
    f.background = f:CreateTexture(nil, "BACKGROUND")
    f.background:SetAllPoints(f)
    f.background:SetTexture(L.background.picture)
    -- Top left, where the original writes its own version over its title picture ("V%d.%d" at (16, 28),
    -- MainMenuPane.cpp:418-421; the picture's bottom left is the publisher's logo) and where nothing of ours is (the
    -- crash notice is at the top's centre, the status line at the bottom's, the menu's column at the bottom right).
    f.version = W.Label(f, L.VersionText(H:GetBuildVersion()), 11, { 0.8, 0.8, 0.85 }, "LEFT")
    f.version:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    local content = CreateFrame("Frame", name .. "Content", f)
    content:SetSize(CONTENT_W, CONTENT_H)
    content:SetPoint("CENTER", f, "CENTER", 0, 0)
    local logo = W.Label(content, "NexusTK", 64, { 0.95, 0.85, 0.55 })
    logo:SetFont(64, "OUTLINE")
    logo:SetPoint("TOP", content, "TOP", 0, 0)
    f.subtitle = W.Label(content, subtitle or "", 14, { 0.75, 0.75, 0.85 })
    f.subtitle:SetPoint("TOP", logo, "BOTTOM", 0, -8)
    f.content = content
    f:SetScript("OnShow", function()
        TK.FitToScreen(content, 8)
        showBackground()
    end)
    f:Hide()
    f:SetScript("OnHide", showBackground)
    table.insert(fullScreens, f)
    return f
end

local function field(parent, label, y, width)
    local fs = W.Label(parent, label, 14, W.gold)
    fs:SetPoint("TOP", parent, "TOP", 0, y)
    local e = W.EditBox(parent, width or 260, 28)
    e:SetFontSize(15)
    e:SetJustifyH("CENTER")
    e:SetPoint("TOP", fs, "BOTTOM", 0, -5)
    return e
end

local function setEnabled(b, on)
    if on then b:Enable() else b:Disable() end
    b:SetAlpha(on and 1 or 0.45)
end

-- s6-ui-login: 4a's dialogs give a field the keyboard as they open (LoginDialogPane and CreateUserDialogPane the
-- account field). An edit box takes the keyboard only once the host has shown and laid it out, so the focus is asked
-- for each frame (the window's OnUpdate, keepFocus) until some box holds it, for at most two seconds.
local function askFocus(win, box)
    win.focusOn, win.focusUntil = box, GetTime() + 2
end

local alert         -- ours, the original's modal alert (L:Alert), made once
local alerts = {}   -- the open alerts' texts, oldest first (ours or the interface's own login screen's draws the newest)
local function alertUp() return #alerts > 0 end

local function keepFocus(win)
    local box = win.focusOn
    if not box then return end
    -- A focus asked for under an alert waits for its OK: the keyboard is the alert's meanwhile.
    if alertUp() then
        win.focusUntil = GetTime() + 2
        return
    end
    if H:IsTextInputActive() or GetTime() > win.focusUntil then
        win.focusOn = nil
        return
    end
    -- a box that does not show yet waits (an interface's own login dialog, before its menu entry opens it)
    if not box:IsVisible() then return end
    box:SetFocus()
end

-- The login box's fields give up the keyboard, and no focus is asked for them any more (a dialog, a book or the lost
-- connection's prompt takes the keys).
local function releaseFields()
    screen.focusOn = nil
    screen.account:ClearFocus()
    screen.password:ClearFocus()
end

-- ----- the server: the enabled saved one, or --server's -----

function L.ParseServer(text)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local host, port = text:match("^([%w%.%-]+):(%d+)$")
    if not host then host, port = text:match("^([%w%.%-]+)$"), "3000" end
    port = tonumber(port)
    if not host or not port or port < 1 or port > 65535 then return nil end
    return host, port
end

-- A fresh install's saved servers, the first one enabled (the owner's answer to round 15: Local covers a local
-- server). The owner's hotfix (2026-10-06): the live NexusTK server and OriginalTK 2 are listed too, never the default,
-- each with its protocol (OriginalTK 2's 5.56, as its recording shows; live speaks 7.5.2, the default:
-- docs/user-related/research/2026-10-06-server-protocol-detect.md). The live address is an official one: the session
-- refuses it before any connect unless Experimental > Official is on (TK.Core.Net.OfficialServers).
-- Local is configured separately (L.LocalServer); Internet lists mentalrage.net, the dev server reached from outside.
-- The owner forwards ports 3000-3009 to it. s6-peer adds its Public-Test seeds independently.
L.SEEDS = require("core.login-seeds")

--- The saved servers; the first time, the seeds, the first enabled.
function L.Servers()
    local list = H:GetServers()
    if #list == 0 then
        for _, s in ipairs(L.SEEDS) do
            H:AddServer(s.name, s.host, s.port)
            if s.version then CS.TK.Modular.ProtocolHost.SetVersion(s.host, s.port, s.version) end
        end
        list = H:GetServers()
    end
    return list
end

--- The server to connect to: { id, name, host, port, address }. In Local the local server's address from its
--- controller. Otherwise --server's (or a tool's) overrides the enabled one for this run; an address not saved yet
--- is saved, named by its address, so its accounts can be saved too (the owner's answer to round 15).
function L.Target()
    if L.mode == "offline" then return L.localTarget or L.LocalServer(H:ClientSettingInt("local_server", "port")) end
    local list = L.Servers()
    local override = H:GetServerOverride()
    if override ~= "" then
        local host, port = L.ParseServer(override)
        if host then
            local address = host .. ":" .. port
            for _, s in ipairs(list) do
                if s.host == host and s.port == port then
                    return { id = s.id, name = s.name, host = host, port = port, address = address }
                end
            end
            local id = H:AddServer(address, host, port)
            return { id = id ~= "" and id or nil, name = address, host = host, port = port, address = address }
        end
    end
    local enabled = H:GetEnabledServer()
    for _, s in ipairs(list) do
        if s.id == enabled then
            return { id = s.id, name = s.name, host = s.host, port = s.port, address = s.host .. ":" .. math.floor(s.port) }
        end
    end
end

-- ----- the status line and the connection -----

local function setStatus(text, r, g, b)
    screen.status:SetText(text)
    screen.status:SetTextColor(r or 0.8, g or 0.8, b or 0.85, 1)
end

--- A server as the status line names it: "name (host:port)".
local function serverText(server) return server.name .. " (" .. server.address .. ")" end

--- Connect while disconnected, Login after acceptance, Cancel while a login is in flight.
function L:UpdateButtons()
    if not screen then return end
    screen.login:SetText(self.busy and "Cancel" or (self.connected and "Login" or "Connect"))
    setEnabled(screen.login, not self.exiting and not self.blocked and not self.connecting)
    setEnabled(screen.newChar, self.connected and not self.busy)
    setEnabled(screen.changePassword, self.connected and not self.busy)
    local available = H:HasServerBundle()
    for mode, b in pairs(screen.modeButtons) do
        local usable = mode == "online" or available
        setEnabled(b, usable and not self.busy)
        W.Tip(b, not usable and L.SERVER_FILES_TIP or nil)
    end
    local server = self.server
    setEnabled(screen.save, server ~= nil and server.id ~= nil and H:CanSavePasswords())
    if presentation then presentation.Refresh() end
end

--- Prepare the selected address without opening a socket. Settings and mode changes always return here.
function L:Ready()
    self.connected, self.connecting = false, false
    self.server = L.Target()
    self:UpdateButtons()
    self:RefreshSaved()
    if self.mode == "server" or (self.mode == "offline" and self.localFailed) then return self:ShowServerState() end
    if self.blocked then return setStatus(self.blocked, 1, 0.35, 0.3) end
    setStatus(self.server and ("Server: " .. serverText(self.server)) or "Choose a server in Settings.")
end

--- Connect's only entry, including finishing a local-server start that this press requested.
-- Wire: TerminalPane::OnTimer 0x0058B470 starts the same connection; the session keeps its greeting, version and
-- login ordering and waits. Only the owner's explicit button triggers it on our screen, and an interface's own login screen
-- as it first shows (L:Show, decision 2026-10-12-original-pregame-screens); changing this changes what the server sees.
-- reconnectByKey: a failed connect's Reconnect in an own connect screen's question (true by Enter, false by the pointer),
-- nil otherwise. WIRE: the new session holds that question's closing wait before it connects (AlertPane::OnControlCommand
-- 0x004A0580's slide, and Enter's Sleep(133), ActivateDefaultControl 0x0049DE70; Session.AlertClosingMs).
function L:Connect(reconnectByKey)
    -- Dedicated Server connects nowhere; Local only once its server runs.
    if self.mode == "server" then return self:ShowServerState() end
    -- s6-play-modes: the server another window of this client ran has ended: this window hosts its own now.
    if self.mode == "offline" and self.localForeign and H:GetForeignServer() ~= "running" then
        self.localTarget, self.localForeign = nil, nil
    end
    if self.mode == "offline" and not self.localTarget then
        -- Login and New Character wait for the local server, from now (review r16 finding 7).
        self.connected = false
        self:UpdateButtons()
        return self:StartLocal()
    end
    self.server = L.Target()
    self.connected, self.connecting, self.serverPending, self.versionRefused = false, true, nil, nil
    setBlocked(nil)
    H:SetLoginRefused(false)
    self.lost, self.failReason, self.failAddress = nil, nil, nil
    self:UpdateButtons()
    self:RefreshSaved()
    if not self.server then return self:Ready() end
    setStatus("Contacting server...")
    -- the connect screen first, in the same frame, so an own title never shows before its connection's greeting (4a
    -- builds MainMenuPane only at the greeting's hand-over, TerminalPane::HandlePacketEvent 0x0058B130)
    terminal("Connecting")
    H:Connect(self.server.host, self.server.port, reconnectByKey ~= nil, reconnectByKey == true)
    -- s6-library round 16: the first connection to a server offers its protocol's prebuilt Library, once per server. A
    -- dialog only: nothing waits for the answer, and nothing is sent for it. Round 24: made once the connection has begun,
    -- so that the offer can wait for a new address's same-server question (prebuild.lua).
    if TK.LibraryPrebuild and self.server then TK.LibraryPrebuild:Offer(self.server.host, self.server.port, self.server.name) end
end

--- The Servers page changed the enabled server: wait for Connect. During a login or away from the login screen the change
--- waits, and applies when the login ends or the screen shows again (review r15 finding 3); during Log Out it waits for
--- the old session's menu, after its 0B and drain (review r17 finding 1).
function L:ServerChanged()
    if not screen then return end
    if self.busy or self.exiting or not screen:IsShown() then
        self.serverPending = true
        return
    end
    self.serverPending = nil
    disconnect()
    -- Credentials and errors belonged to the previous address; choose its account again after the change.
    screen.password:SetText("")
    screen.error:SetText("")
    self.commandLine = nil
    setBlocked(nil) -- a server/settings change lifts the old block; it opens no connection
    self:Ready()
end

--- A login that ended without the world, back on the login screen: a server change made meanwhile applies now.
local function applyPendingServer()
    if L.serverPending and screen and screen:IsShown() and not L.busy then L:ServerChanged() end
end

local function failed()
    L.connected, L.connecting = false, false
    L:UpdateButtons()
    -- a block's and a lost connection's messages are theirs (an alert, the session's dialog); otherwise the connect
    -- screen asks Reconnect or Leave (TerminalPane::OnTimer 0x0058B470's question)
    if L.blocked or L.lost or (presentation ~= nil and L.menuTransferFailed) then return terminal(nil) end
    terminal("Failed")
    local why = L.failReason and (": " .. L.failReason) or ""
    -- The failed socket may be a transfer target, not the login server chosen in settings. Display only; no retry or send.
    local address = L.failAddress or (L.server and L.server.address)
    if address then setStatus("Failed to connect to " .. address .. why .. ".", 1, 0.55, 0.35) end
end

-- Only an explicit Connect can have a local start pending; this tick finishes that start, never a network retry.
local function tickServerWait()
    -- s6-play-modes: Local waiting for another window's server to start (L:StartLocal) looks again.
    if L.otherAt and GetTime() >= L.otherAt then
        L.otherAt = nil
        return L:Connect()
    end
    -- s6-play-modes: Dedicated Server without its own server running shows another window's, or offers Start: it looks
    -- again every two seconds, so that window's server starting or ending shows (with Start) while the panel is open.
    if L.otherShown and GetTime() >= (L.otherLookAt or 0) then
        L.otherLookAt = GetTime() + 2
        if H:GetForeignServer() ~= L.otherShown then L:ShowServerState() end
    end
end

-- ----- the saved accounts panel -----

local function buildSaved()
    local p = W.Panel(screen.content, "TKLoginSaved")
    p:SetSize(230, 330)
    p:SetPoint("TOPRIGHT", screen.content, "TOPRIGHT", -20, -136)
    local t = W.Label(p, "Saved Accounts", 14, W.gold)
    t:SetPoint("TOP", p, "TOP", 0, -12)
    local hint = W.Label(p, "Choose an account.\nThe trash can deletes it.", 11, { 0.7, 0.7, 0.7 })
    hint:SetPoint("BOTTOM", p, "BOTTOM", 0, 12)
    p.buttons, p.trash = {}, {}
    for i = 1, L.MAX_SAVED do
        local b = W.Button(p, "", 170, 24)
        b:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -40 - (i - 1) * 28)
        b:SetScript("OnClick", function(self) L:LoginSaved(self.account) end)
        local trash = W.IconButton(p, "tk:trash", 20, function(self) L:AskDeleteSaved(self.account) end)
        trash:SetPoint("LEFT", b, "RIGHT", 8, 0)
        p.buttons[i], p.trash[i] = b, trash
    end
    -- More accounts than rows (review r15 finding 4): the arrows and the wheel scroll the list a row at a time.
    p.top = 0
    local function scroll(delta)
        p.top = p.top + delta
        L:RefreshSaved()
    end
    p.up = W.IconButton(p, "tk:arrow-up", 16, function() scroll(-1) end)
    p.up:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, -14)
    p.down = W.IconButton(p, "tk:arrow-down", 16, function() scroll(1) end)
    p.down:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, -40 - L.MAX_SAVED * 28)
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, delta) scroll(-delta) end)
    screen.saved = p
end

--- The accounts saved for the server on the right (when there are any and the list is on), the login box beside it.
function L:RefreshSaved()
    if not screen then return end
    local id = self.server and self.server.id
    local names = {}
    if id then
        local text = H:GetSavedAccounts(id)
        for name in text:gmatch("[^\n]+") do names[#names + 1] = name end
    end
    local shown = TK.Machine:Get().showRecent ~= false and #names > 0 and self.mode ~= "server"
    screen.saved:SetShown(shown)
    -- The login box moves to the middle when there is no list beside it.
    screen.box:ClearAllPoints()
    if shown then
        screen.box:SetPoint("TOPLEFT", screen.content, "TOPLEFT", 40, -136)
    else
        screen.box:SetPoint("TOP", screen.content, "TOP", 0, -136)
    end
    local p = screen.saved
    p.top = math.max(0, math.min(p.top, #names - L.MAX_SAVED))
    for i, b in ipairs(p.buttons) do
        local name = names[i + p.top]
        b.account, p.trash[i].account = name, name
        b:SetText(name or "")
        b:SetShown(name ~= nil)
        p.trash[i]:SetShown(name ~= nil)
    end
    p.up:SetShown(p.top > 0)
    p.down:SetShown(p.top + L.MAX_SAVED < #names)
end

--- A saved account fills the fields; only an already accepted connection can submit it.
function L:LoginSaved(account)
    local id = self.server and self.server.id
    if not account or not id then return end
    local password = H:GetSavedPassword(id, account)
    screen.account:SetText(account)
    screen.password:SetText(password or "") -- an unreadable saved password must not leave another account's password
    screen.error:SetText("")
    if not password then
        screen.password:SetFocus()
        return self:Error("The saved password cannot be read on this Windows account: type it.")
    end
    password = nil
    if self.connected then return self:Submit() end
    askFocus(screen, screen.password)
end

--- The trash can: asks, and Yes deletes the saved account.
function L:AskDeleteSaved(account)
    local id = self.server and self.server.id
    if not account or not id then return end
    W.Confirm("Delete the saved information for " .. account .. "?", function()
        H:DeleteSavedAccount(id, account)
        L:RefreshSaved()
    end)
end

-- ----- the play modes (plan D23) and the packaged server -----

-- The owner's names (2026-10-02); the keys are settings.toml's.
L.MODE_TEXT = { online = "Internet", offline = "Local", server = "Dedicated" }
L.SERVER_FILES_TIP = "Get the server files and restart the client, or set a folder in Settings > Servers > Local Server."
L.mode = "online"
L.CONSOLE_LINES = 12

local function loadMode()
    local m = H:ClientSettingString("login", "mode")
    L.mode = L.MODE_TEXT[m] and m or "online"
    -- A remembered local mode with missing files shows Internet for this run; keep its saved choice for a restart.
    if L.mode ~= "online" and not H:HasServerBundle() then L.mode = "online" end
end

--- The login box in Internet and Local; in Dedicated Server the host panel and the readme instead. The host panel
--- (its Start button only) also comes in Local when the local server failed or ended.
function L:ApplyModeLayout()
    if not screen then return end
    local m = self.mode
    screen.modes:SetValue(m)
    screen.box:SetShown(m ~= "server")
    screen.newChar:SetShown(m ~= "server")
    screen.changePassword:SetShown(m ~= "server")
    local state = H:GetServerState()
    local retry = m == "offline" and (state == "failed" or state == "stopped") and not self.localTarget and self.localAsked
    screen.host:SetShown(m == "server" or retry)
    screen.host:ClearAllPoints()
    if m == "server" then
        screen.host:SetPoint("TOPLEFT", screen.content, "TOPLEFT", 0, -136)
    else
        screen.host:SetPoint("TOP", screen.box, "BOTTOM", 0, -10)
    end
    for _, part in ipairs({ screen.host.address, screen.host.consoleBox, screen.host.input, screen.readme }) do
        part:SetShown(m == "server")
    end
    self:RefreshSaved()
end

--- A one-of mode choice: Internet, Local or Dedicated. The connection ends; leaving Local or
--- Dedicated Server stops the packaged server (it saves and ends by itself).
function L:SetMode(mode)
    if self.busy or not L.MODE_TEXT[mode] or mode == self.mode then return end
    if mode ~= "online" and not H:HasServerBundle() then return end
    local old = self.mode
    self.mode = mode
    H:ClientSettingSetString("login", "mode", mode)
    H:ClientSettingsSave()
    disconnect()
    self.connected, self.localTarget, self.localAsked, self.localFailed, self.localForeign = false, nil, false, nil, nil
    setBlocked(nil)
    self.otherAt, self.otherShown = nil, nil
    self:UpdateButtons()   -- at once, before any server starts (review r16 finding 7)
    if old ~= "online" then H:ServerStop() end
    self:ApplyModeLayout()
    screen.password:SetText("")
    screen.error:SetText("")
    self.commandLine = nil
    self:Ready()
    -- Leaving the terminal restores the account field's keyboard when its box is visible again.
    if mode ~= "server" then askFocus(screen, screen.account) end
end

--- Local: the local server starts (after the last one has ended, if one is still stopping).
function L:StartLocal()
    self.localTarget, self.localAsked, self.localFailed, self.connecting = nil, true, nil, true
    self:UpdateButtons()
    if not H:HasServerBundle() then
        self.connecting = false
        self:UpdateButtons()
        return setStatus("Local server files are missing.", 1, 0.35, 0.3)
    end
    -- s6-play-modes: another window of this client (the same folder) runs its server: this one plays on it too, and
    -- leaves it to that window; one still starting is looked at again in a moment.
    local other, _, otherIp, otherLogin = H:GetForeignServer()
    if other == "running" then
        self.localTarget, self.localForeign = L.LocalServer(otherLogin), true
        self:ApplyModeLayout()
        return self:Connect()
    elseif other ~= "" then
        self.otherAt = GetTime() + 2
        return setStatus("The local server is starting in another window...")
    end
    local state, mode, ip, login = H:GetServerState()
    -- s6-play-modes: the Local Server page's "Allow Internet Connections In Local Mode" (off by default): on, the
    -- server listens on every network, as Dedicated Server's does.
    local wanted = H:ClientSettingBool("local_server", "internet") and "external" or "local"
    -- A local server already running (a UI reloaded in Local keeps its controller) is connected to at once
    -- (review r16 finding 6); one starting connects when it runs.
    if state == "running" and mode == wanted then
        self.localTarget = L.LocalServer(login)
        self:ShowServerState()
        return self:Connect()
    end
    if state ~= "starting" then H:ServerStart(wanted) end
    self:ShowServerState()
end

--- The host panel's button: Start Server or Stop Server (Dedicated Server), or Start again (Client Host after a failure).
function L:HostButton()
    local state = H:GetServerState()
    if self.mode == "offline" then return self:StartLocal() end
    if state == "starting" or state == "running" then H:ServerStop() else H:ServerStart("external") end
    self:ShowServerState()
end

--- A controller's reason as words ("port_3000_in_use": "port 3000 in use").
local function reasonText(reason)
    if reason == "already_running" then return "it already runs in another window of this client" end
    return (reason or "") ~= "" and (reason:gsub("_", " ")) or "no reason given"
end

--- The status line, the host panel's button and address from the packaged server's state.
function L:ShowServerState()
    if not screen or self.mode == "online" then return end
    local state, mode, ip, login, reason, waiting = H:GetServerState()
    local host = screen.host
    local up = state == "starting" or state == "running"
    if self.mode == "offline" and not up and not waiting then self.connecting = false; self:UpdateButtons() end
    -- s6-play-modes: in Dedicated Server, another window of this client may run this folder's server: shown, not started.
    local other, otherIp, otherLogin = "", "", 0
    local watching = self.mode == "server" and not up and not waiting
    if watching then
        local _
        other, _, otherIp, otherLogin = H:GetForeignServer()
    end
    self.otherShown = watching and other or nil -- what tickServerWait compares with
    if other == "running" then ip, login = otherIp, otherLogin end
    host.start:SetText(up and "Stop Server" or "Start Server")
    setEnabled(host.start, other == "")
    host.address:SetText(self.mode == "server" and (state == "running" or other == "running")
        and ("Other players connect to " .. ip .. ":" .. login) or "")
    local server = self.mode == "server" and "server" or "local server"
    if other ~= "" then
        setStatus("The server runs in another window of this client.", 0.55, 0.9, 0.55)
    elseif waiting or state == "stopping" then
        setStatus("Stopping server...")
    elseif state == "starting" then
        setStatus("Starting " .. server .. "...")
    elseif state == "running" then
        if self.mode == "server" then setStatus("Server running.", 0.55, 0.9, 0.55) end
    elseif state == "failed" then
        setStatus("The " .. server .. " failed: " .. reasonText(reason) .. ".", 1, 0.35, 0.3)
    elseif self.mode == "server" then
        setStatus("Server stopped.")
    elseif self.localAsked then
        setStatus("The local server stopped.", 1, 0.55, 0.35)
    end
    self:ApplyModeLayout()
    self:RefreshConsole()
    self:RefreshReadme()
end

--- s6-play-modes: the terminal's line (Enter): a command for the running server's console; the line keeps the keyboard
--- for the next one.
function L:SendCommand(text)
    local line = screen.host.input
    line:SetText("")
    if text:match("%S") and not H:ServerCommand(text) then
        setStatus(H:GetForeignServer() ~= "" and "The server runs in another window: type its commands there."
            or "The server is not running: Start Server first.", 1, 0.55, 0.35)
    end
    line:SetFocus()
end

--- s6-play-modes: the readme beside the terminal: what the Dedicated Server is, the address it gives the players, and
--- every console command with what it does, from the server's own list (rtkctl commands: H:GetServerCommands).
function L:RefreshReadme()
    local r = screen and screen.readme
    if not r or not r:IsShown() then return end
    local state, _, ip, login = H:GetServerState()
    if state ~= "running" then -- s6-play-modes: another window's server
        local other, _, otherIp, otherLogin = H:GetForeignServer()
        if other == "running" then state, ip, login = other, otherIp, otherLogin end
    end
    r.intro:SetText("This client only hosts the server. To play on it, open the client again (on this PC or another), "
        .. "choose Internet, and connect to the address below (Settings, Servers).\n\n"
        .. (state == "running" and ("Address: " .. ip .. ", port " .. login .. ".")
            or "Address: shown here once the server runs (its ports and address: Settings, Local Server).")
        .. "\n\nType a command in the line under the console and press Enter.")
    if not r.rows then
        local list = H:GetServerCommands()
        if list ~= "" then
            r.rows = {}
            for line in list:gmatch("[^\n]+") do
                local name, args, what = line:match("^([^\t]*)\t([^\t]*)\t(.*)$")
                if name then
                    local row = { name = W.Label(r.scroll.content, name .. (args ~= "" and (" " .. args) or ""), 12, W.gold, "LEFT"),
                                  text = W.Label(r.scroll.content, what, 11, { 0.8, 0.8, 0.85 }, "LEFT") }
                    row.text:SetWordWrap(true)
                    row.text:SetWidth(r.width - 12)
                    r.rows[#r.rows + 1] = row
                end
            end
        end
    end
    local y = r.intro:GetStringHeight() + 12
    r.header:SetPoint("TOPLEFT", r.scroll.content, "TOPLEFT", 0, -y)
    r.header:SetText(r.rows and "Commands" or "Commands: reading the server's list...")
    y = y + 20
    for _, row in ipairs(r.rows or {}) do
        row.name:SetPoint("TOPLEFT", r.scroll.content, "TOPLEFT", 0, -y)
        row.text:SetPoint("TOPLEFT", r.scroll.content, "TOPLEFT", 12, -(y + 15))
        y = y + 15 + row.text:GetStringHeight() + 6
    end
    r.scroll.content:SetSize(r.width, y)
    r.scroll.Refresh()
end

function L:RefreshConsole()
    local host = screen and screen.host
    if not host or not host.consoleBox:IsShown() then return end
    local text = H:GetServerConsole(L.CONSOLE_LINES + host.scroll)
    local lines = {}
    for line in text:gmatch("[^\n]+") do lines[#lines + 1] = line end
    -- s6-play-modes: wrapped, and the newest of them that fit the box.
    local count = math.min(L.CONSOLE_LINES, #lines)
    local first, limit = 1, host.consoleBox:GetHeight() - 16
    host.console:SetText(table.concat(lines, "\n", 1, count))
    while first < count and host.console:GetStringHeight() > limit do
        first = first + 1
        host.console:SetText(table.concat(lines, "\n", first, count))
    end
end

L.LOCAL_NAME = "Local server"

--- Local's account key is dedicated; use loopback even when the server advertises its public address to remote users.
function L.LocalServer(port)
    port = port and port > 0 and port or H:ClientSettingInt("local_server", "port")
    local id = H:LocalServerAccountKey(port)
    return { id = id, name = L.LOCAL_NAME, host = "127.0.0.1", port = port, address = "127.0.0.1:" .. port }
end

TK.On("TK_SERVER_STATE", function(_, state, mode, ip, login, reason)
    if not screen then return end
    -- Local: at running the screen connects to the address the controller gives, through the Client path (its
    -- mode is external with Allow Internet Connections).
    if L.mode == "offline" then
        if state == "running" and not L.localTarget and L.connecting then
            L.localTarget = L.LocalServer(login)
            L:ShowServerState()
            return L:Connect()
        elseif state ~= "running" and L.localTarget then
            -- The local server went away under the connection (review r16 finding 5): back to the login screen, from
            -- the world too, with its reason; its Start tries again, and nothing restarts by itself.
            L.localTarget, L.localFailed = nil, true
            local message = state == "failed"
                and ("The local server failed: " .. ((reason or "") ~= "" and reason or "no reason given") .. ".")
                or "The local server stopped."
            if TK.GameState:InWorld() then
                L:LogOut(message)
            else
                disconnect()
                L.connected, L.connecting = false, false
                L:UpdateButtons()
                L:Error(message)
            end
        end
    end
    L:ShowServerState()
end)

TK.On("TK_SERVER_CONSOLE", function() L:RefreshConsole() end)
TK.On("TK_SERVER_COMMANDS", function() L:RefreshReadme() end)

--- Dedicated Server's panel: Start / Stop, the address other players use, the server's console (the wheel scrolls back
--- through the last lines the host keeps) and the terminal's line under it; the readme beside them (s6-play-modes).
buildHost = function()
    local host = CreateFrame("Frame", "TKLoginHost", screen.content)
    host:SetSize(400, 280)
    host.start = W.Button(host, "Start Server", 200, 34, "red", function() L:HostButton() end)
    host.start:GetFontString():SetFont(16, "")
    host.start:SetPoint("TOP", host, "TOP", 0, 0)
    host.address = W.Label(host, "", 14, W.gold)
    host.address:SetPoint("TOP", host.start, "BOTTOM", 0, -10)
    local box = W.Panel(host, "TKLoginConsole")
    box:SetBackdropColor(0.02, 0.02, 0.03, 0.9)
    box:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -70)
    box:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 32)
    box:EnableMouseWheel(true)
    host.scroll = 0
    box:SetScript("OnMouseWheel", function(_, delta)
        host.scroll = math.max(0, host.scroll + delta * 3)
        L:RefreshConsole()
    end)
    host.console = W.Label(box, "", 11, { 0.8, 0.85, 0.8 }, "LEFT")
    host.console:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
    host.console:SetWidth(384)
    host.console:SetWordWrap(true)
    host.consoleBox = box
    host.input = W.EditBox(host, 400, 26)
    host.input:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
    host.input:SetScript("OnEnterPressed", function(self) L:SendCommand(self:GetText()) end)
    host:Hide()
    screen.host = host

    local r = W.Panel(screen.content, "TKLoginReadme")
    r:SetBackdropColor(0.03, 0.03, 0.06, 0.85)
    r.width = 240
    r:SetSize(270, 280)
    r:SetPoint("TOPRIGHT", screen.content, "TOPRIGHT", 0, -136)
    local title = W.Label(r, "Dedicated Server", 15, W.gold)
    title:SetPoint("TOP", r, "TOP", 0, -8)
    r.scroll = W.ScrollArea(r)
    r.scroll:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -32)
    r.scroll:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -16, 8)
    r.scroll.wheelStep = 30
    r.intro = W.Label(r.scroll.content, "", 11, { 0.85, 0.85, 0.9 }, "LEFT")
    r.intro:SetPoint("TOPLEFT", r.scroll.content, "TOPLEFT", 0, 0)
    r.intro:SetWidth(r.width)
    r.intro:SetWordWrap(true)
    r.header = W.Label(r.scroll.content, "", 13, W.gold, "LEFT")
    r:Hide()
    screen.readme = r
end

-- ----- the login screen -----

--- A full screen's status line at its bottom: ours, and an interface's own login screen's (L:ApplyScreens).
function L.StatusLine(parent)
    local status = W.Label(parent, "", 14, { 0.8, 0.8, 0.85 })
    -- s6-protocol round 66: a failure's reason can be long, so the line spans the screen (20 px in from each side) and
    -- wraps upwards, centred, whatever the screen's width and UI scale.
    status:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 20, 40)
    status:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 40)
    status:SetWordWrap(true)
    status:SetJustifyH("CENTER")
    return status
end

local function buildScreen()
    loadMode()
    screen = fullScreen("TKLoginScreen", "")

    local box = W.Panel(screen.content, "TKLoginBox")
    box:SetBackdropColor(0.03, 0.03, 0.06, 0.8)
    box:SetSize(320, 280)
    screen.box = box
    screen.account = field(box, "Account Name", -14)
    screen.account:SetMaxLetters(L.MAX_ACCOUNT)
    screen.password = field(box, "Password", -76)
    screen.password:SetMaxLetters(L.MAX_PASSWORD)
    screen.password:SetPassword(true)
    screen.save = W.Check(box, "Save account information")
    screen.save:SetPoint("TOP", box, "TOP", 0, -140)
    screen.login = W.Button(box, "Connect", 200, 34, "red", function() L:LoginButton() end)
    _G.TKLoginConnect = screen.login -- existing gate control log exposes it to posted-input tools
    screen.login:GetFontString():SetFont(16, "")
    screen.login:SetPoint("TOP", box, "TOP", 0, -176)
    screen.error = W.Label(box, "", 13, { 1, 0.35, 0.3 })
    screen.error:SetWordWrap(true)
    screen.error:SetWidth(296)
    screen.error:SetPoint("TOP", screen.login, "BOTTOM", 0, -10)

    -- Enter activates Connect while disconnected; after acceptance an empty password still takes the caret first.
    -- Wire: the key uses the same explicit entry as the button. TerminalPane 0x0058B470/0x0058B130 and
    -- LoginDialogPane::OnControlCommand 0x004FAD00 still own the handshake and login wait; changing this changes
    -- what the server sees. Tab and Shift+Tab retain the host's field order.
    screen.account:SetScript("OnEnterPressed", function()
        if not L.connected or L.busy then return L:LoginButton() end
        if screen.password:GetText() == "" then screen.password:SetFocus() else L:LoginButton() end
    end)
    screen.password:SetScript("OnEnterPressed", function() L:LoginButton() end)
    -- The login field that last had the keyboard, for a book to give it back: a press on a button takes the keyboard
    -- from the field before the button's click runs (review r2, 2).
    for _, box in ipairs({ screen.account, screen.password }) do
        box:HookScript("OnEditFocusGained", function(self) screen.lastField = self end)
    end

    -- ui-core's shared one-of group owns the selection, including pressing the already selected button.
    screen.modes = W.OneOf(screen.content, "", 320, function(mode) L:SetMode(mode) end)
    screen.modes:SetSize(320, 24)
    screen.modes.title:Hide()
    screen.modes:SetPoint("BOTTOM", box, "TOP", 0, 8)
    screen.modeButtons = {}
    for i, mode in ipairs({ "online", "offline", "server" }) do
        local b = W.Button(screen.modes, L.MODE_TEXT[mode], 102, 24)
        b:SetPoint("LEFT", screen.modes, "LEFT", (i - 1) * 109, 0)
        screen.modes:Add(b, mode)
        screen.modeButtons[mode] = b
        _G["TKLoginMode" .. i] = b
    end
    screen.modes:SetValue(L.mode)

    screen.status = L.StatusLine(screen)
    -- Head note 47: without the art packs a live login can't draw the world; said plainly, before the login, above the
    -- status line (the top is the crash notice's).
    screen.noArt = W.Label(screen, TK.Art.NO_PACKS_TEXT, 15, { 1, 0.7, 0.3 })
    screen.noArt:SetPoint("BOTTOM", screen.status, "TOP", 0, 10)
    screen.noArt:SetShown(not TK.Art.Available())

    -- s6-ui-login: the original menu's other entries (MainMenuPane::ActivateMenuItem 0x004F7A10: 2 Change password,
    -- 3 Story, 4 History, 5 Exit), bottom right as WoW's login screen has them; the books only with the packs.
    local column = {
        { "settings", "Settings", function() TK.Settings:Open("servers") end },
        { "library", "Library", function() TK.Library:Open() end }, -- s6-library round 2
        { "newChar", "New Character", function() L:ShowCreate() end },
        { "changePassword", "Change Password", function() L:OpenChangePassword() end },
        { "story", "Story", function() L:OpenBook("STORY.EPF") end },
        { "history", "History", function() L:OpenBook("HISTORY.EPF") end },
        { "quit", "Quit", function() L:Quit() end },
    }
    for i, c in ipairs(column) do
        local b = W.Button(screen, c[2], 150, 28, nil, c[3])
        b:SetPoint("BOTTOMRIGHT", screen, "BOTTOMRIGHT", -24, 24 + (#column - i) * 36)
        screen[c[1]] = b
        -- Named for the gate's driver (TKLoginChangePassword, TKLoginStory...; s6-gate round 38's 0x26 scenario presses
        -- Change Password): gate mode logs a named control's place while it shows (core/gatecontrols.lua).
        _G["TKLogin" .. (c[1]:gsub("^%l", string.upper))] = b
    end
    screen.story:SetShown(TK.Art.Image("STORY.EPF", 0, L.BOOK_PALETTE) ~= nil)
    screen.history:SetShown(TK.Art.Image("HISTORY.EPF", 0, L.BOOK_PALETTE) ~= nil)
    screen:SetScript("OnUpdate", function(self)
        tickServerWait()
        keepFocus(self)
    end)

    buildSaved()
    buildHost()
end

-- ----- an interface's own login screen (s6-ui-core round 86) -----
--
-- The owner's answer of 2026-10-12 to the XML interfaces' choice 3: 7.x and 5.x have the real client's whole interface,
-- its login screen included, behind Settings > Experimental's Original Login Screens (off: ours). Decision
-- 2026-10-12-original-pregame-screens: such a screen is its interface's XML twin's (the interface's login.screens, a
-- module only the twin has), and it is a presentation over this file's logic. The connection, the login and its wait, the
-- refusals and the menu's other entries stay here, one code for every screen, so what is sent is the same whichever
-- screen shows. The module is a function(L, screen) that makes and returns the presentation:
--   frame                its full-screen frame on our screen, over it (our login box hides meanwhile);
--   account, password    its fields, which the logic reads, fills and focuses in place of ours;
--   status               its status line (L.StatusLine), in place of ours;
--   Show()               the screen shows (L:Show), as the original's menu opens;
--   Refresh()            the logic's state changed (L:UpdateButtons: connected, busy, lost);
--   Message(text, progress)   L:Error's message;
--   Key(bare, key)       a key down while no box has the keyboard and no window is over it (bare without its modifiers,
--                        key with them, e.g. "SHIFT-TAB"): true when it took it;
--   passwordDialog       optional: its Change Password dialog, which L:OpenChangePassword opens in place of ours: the
--                        fields account, current, new and again, ok, cancel, and dim (the wait's dimmer), wired by
--                        L.WirePasswordDialog, so the logic checks it, sends 0x26 and takes the answer as with ours;
--   ShowAlert(text, opened), HideAlert()   optional: L:Alert's alerts drawn its way in place of ours: the newest's text
--                        (opened: it has just opened, not an older one shown again), and none left. Its OK calls
--                        L:CloseAlert(); the keys and the modal rule stay the logic's;
--   book                 optional: its Story and History books' own pages, { Image(file, frame): the frame's key and
--                        size, or nil; Turn(page): the page a turn goes to }, in place of the packs' 7.5.2 pages;
--   Terminal(state)      optional: its connect screen (the original's TerminalPane) while a connection starts from it:
--                        "Connecting" (the connect: its connecting alert), "Greeting" (connected, the greeting awaited),
--                        "Failed" (the connect failed: its Reconnect, which calls L:Connect(byKey), and its Leave, L:Exit()),
--                        or nil (none: the greeting's hand-over to the menu, a lost connection's own dialog, a block);
--   createDialog         optional: its New User dialog, which L:ShowCreate opens in place of ours, over its menu: the
--                        fields account, password and repeatBox, dim (the request's dimmer) and ShowLook() (its look
--                        drawn from look and facing, which L:ShowCreate and the session's draws set and its own controls
--                        change; its pictures from L.CreationPreview, L.CreationCell and L.CreationSwatch; the look's
--                        nation is carried as creationNation: 7.5.2's 4a 0x0052F160 sends fixed 0; 5.33's 0x47BA30
--                        sends the choice + 1). Changing it changes what the server sees. Its OK is L:SubmitCreate and
--                        its Cancel L:CancelCreate, so the logic checks it and sends 0x02 and 0x04 as with ours; its
--                        messages are Message's (its alert). L:ShowCreate sets its OnUpdate (the fields' focus).
-- The module returns nil when it cannot draw (5.x's title without the 5.33 set): ours shows. Dedicated Server keeps ours
-- (it hosts), and so does a client without the art packs.

--- The module of the active interface's own login screen when it is in use, or nil for ours.
local function screensModule()
    if TK.Machine:Get().originalScreens ~= true or not TK.Interfaces:Xml() or L.mode == "server"
        or not TK.Art.Available() then
        return nil
    end
    return (TK.Interfaces:Active().login or {}).screens
end

--- Our screen or the interface's own, as the setting, the form and the play mode now ask: at each L:Show, at the
--- setting's change and at the form's switch (TK.Interfaces:SwitchFormNow). A presentation is made once and kept. The
--- account typed and the status carry over. Drawing only: nothing is sent.
function L:ApplyScreens()
    if not screen then return end
    local module = screensModule()
    if (presentation and presentation.module) == module then return end
    local account, status = screen.account:GetText(), screen.status:GetText()
    if presentation then presentation.frame:Hide() end
    screen.ours = screen.ours or { account = screen.account, password = screen.password, status = screen.status }
    screen.made = screen.made or {}
    presentation = nil
    if module then
        presentation = screen.made[module] or require(module)(L, screen)
        if presentation then
            presentation.module = module
            screen.made[module] = presentation
        end
    end
    local fields = presentation or screen.ours
    screen.account, screen.password, screen.status = fields.account, fields.password, fields.status
    screen.account:SetText(account)
    screen.status:SetText(status)
    screen.content:SetShown(presentation == nil)
    if presentation then
        presentation.frame:Show()
        if screen:IsShown() then presentation.Show() end
    end
    showBackground()
end

--- A field of an interface's own login screen asks for the keyboard as it opens, as ours do (askFocus).
function L:FocusField(box) askFocus(screen, box) end

--- A screen's message line: red for an error (the default), grey for progress (L:Error, L:CreateMessage).
local function showMessage(label, text, progress)
    label:SetText(text)
    if progress then label:SetTextColor(0.8, 0.8, 0.85, 1) else label:SetTextColor(1, 0.35, 0.3, 1) end
end

--- Shows a message under the Login button: red for an error (the default), grey for progress.
function L:Error(text, progress)
    if presentation then
        presentation.Message(text, progress) -- an interface's own screen says it its way (its alert)
        return false
    end
    showMessage(screen.error, text, progress)
    return false
end

local function setBusy(on)
    L.busy = on
    L:UpdateButtons()
end

--- Connect, Login, or the existing Cancel during login. Cancel waits for a new press instead of reconnecting.
-- Wire: the session owns TerminalPane's handshake and LoginDialogPane::OnControlCommand 0x004FAD00's 200–599 ms
-- wait and packet bytes; this screen starts neither implicitly. Changing this input path changes what the server sees.
function L:LoginButton()
    if self.busy then
        disconnect()
        setBusy(false)
        self:Ready()
        return self:Error("Cancelled.", true)
    end
    -- The keyboard observes the button's disabled states too: another Enter during the handshake starts nothing.
    -- Wire: TerminalPane's single handshake (0x0058B470/0x0058B130) must finish before another explicit action;
    -- restarting it here would send another greeting/version and change what the server sees.
    if self.connecting or self.blocked or self.exiting then
        -- EndLiveEdit finishes the Enter after this callback; restore the same field on the next UI update.
        askFocus(screen, screen.lastField or screen.account)
        return false
    end
    if not self.connected then return self:Connect() end
    return self:Submit()
end

--- Checks the boxes and logs in on the connection. The password goes to C# at once and is forgotten here.
function L:Submit()
    if self.busy then return false end
    if not self.connected then return self:Error("Connect to the server first.") end
    local account = screen.account:GetText()
    local password = screen.password:GetText()
    screen.password:SetText("")
    local length = #password
    if account == "" then return self:Error("Enter your account name.") end
    if not TK.Machine.IsAccountName(account) then
        return self:Error("An account name has at most " .. L.MAX_ACCOUNT .. " letters, digits, '-' or '_'.")
    end
    if length == 0 then return self:Error("Enter your password.") end
    if length > L.MAX_PASSWORD then return self:Error("A password has at most " .. L.MAX_PASSWORD .. " characters.") end
    TK.Machine:RememberAccount(account)
    self.account = account
    screen.account:ClearFocus()
    screen.password:ClearFocus()
    setBusy(true)
    self:Error("Logging in...", true)
    -- (an interface's own screen has no Save account information: nothing is saved through it)
    local saveOn = not presentation and screen.save:GetChecked() and self.server.id or ""
    -- Wire: LoginDialogPane::OnControlCommand 0x004FAD00 sends this same login after its original wait; changing it
    -- changes what the server sees. The session reads the character's ignore list with its profile.
    H:Login(account, password, saveOn)   -- the session reads the character's ignore list with its profile (s6-layout round 5)
    password = nil
    return true
end

--- Enters the world as the given account: the session's world when online, the mock world otherwise.
function L:EnterWorld(account)
    self.account = account
    __tk:SetSessionAccount(account)
    setBusy(false)
    screen.error:SetText("")
    screen.account:ClearFocus()
    screen.password:ClearFocus()
    screen:Hide()
    if create then create:Hide() end
    TK.Settings:Close()
    -- The character's own hotbars and layout (plan 5.14).
    TK.Characters:Enter(account)
    TK.GameState:Set("world")
    TK.FireEvent("PLAYER_ENTERING_WORLD")
end

--- Play Offline: the local mock world, explicitly; nothing is sent there.
function L:PlayOffline()
    disconnect()
    self.connected = false
    H:UseOfflineWorld()
    local account = screen.account:GetText()
    self:EnterWorld(account ~= "" and account or "Offline")
end

--- Shows the login screen. An open menu connection survives Log Out; a closed one waits for Connect.
function L:Show(message)
    if not screen then buildScreen() end
    self:ApplyScreens()
    __tk:SetSessionAccount("")
    if create then create:Hide() end
    TK.GameState:Set("login")
    local recent = TK.Machine:Get().recentAccounts
    screen.account:SetText(self.account or recent[1] or "")
    screen.password:SetText("")
    screen.subtitle:SetText("Log in to a server, or host one")
    setBusy(false)
    screen.error:SetText("")
    if message then self:Error(message) end
    screen:Show()
    if presentation then presentation.Show() end
    CrashNotice:Show(screen) -- s6-crash-reports seam
    -- The account field has the keyboard, as in the original's login dialog (s6-ui-login).
    if self.mode ~= "server" then askFocus(screen, screen.account) end
    self:ApplyModeLayout()
    -- A D22 block stays through New Character and Back (review r15 finding 2): only a change of servers lifts it.
    if self.serverPending and not self.exiting then
        self:ServerChanged()
    elseif not self.connected and not self.connecting and not self.exiting and not self.blocked and not self.lost
        and not self.resuming then
        self:Ready()
        -- WIRE (decision 2026-10-12-original-pregame-screens, choice 4): an interface's own login screen connects as it
        -- first shows, once a run, as 7.5.2 connects at its start (TerminalPane::OnTimer 0x0058B470, after its logo);
        -- ours waits for Connect (the owner, 2026-10-06). The connection and its handshake are L:Connect's, the same bytes
        -- and waits; only the moment it starts follows the original. Changing this changes when the server sees the
        -- client connect. (A local server that failed is started again only by a press, as on ours.)
        if presentation and not self.titleConnected and not self.localFailed then
            self.titleConnected = true
            self:Connect()
        end
    else
        self:RefreshSaved()
    end
    if self.blocked and not message then self:Error(self.blocked) end
    -- --login fills the fields; Connect is still an explicit press and Login waits for acceptance.
    local login = H:TakeCommandLineLogin()
    local account, password = login:match("^([^:]+):(.*)$")
    if account then
        screen.account:SetText(account)
        self.commandLine = password
    end
end

--- Leaves the world for the login screen; every window closes. In a game the session goes back to its menu on the
--- same connection (the original's exit to the menu, head note 28); otherwise the connection ends and the screen
--- waits for Connect.
local function leaveWorld()
    TK.KeyBindMode:Disable()
    if TK.EditMode.unlocked then TK.EditMode:Lock() end
    ClearCursor()
    GameTooltip:Hide()
    TK.GameMenu:Close()
    TK.Settings:Close()
    TK.FireEvent("PLAYER_LEAVING_WORLD")
end

function L:LogOut(message)
    if not TK.GameState:InWorld() then return end
    leaveWorld()
    self.connected = false
    self.exiting = not message and H:IsOnline() and H:ExitToMenu()
    if not self.exiting then disconnect() end
    H:UseOfflineWorld()
    self:Show(message)
    if self.exiting then setStatus("Returning to the menu...") end
end

--- s6-ui-core (round 32): the session went back to its menu by itself, on the lost connection's Reconnect: 3 s after the
--- new connection's greeting it tore the game screen down without 0B and sent "baram" and the version
--- (ReconnectDialog::OnTimer, timer 1). The login screen shows, on that connection; the player logs in again.
function L:BackToMenu(returningMenu)
    leaveWorld()
    -- A native Menu callback applies a pending address below, after its existing exit/queue drain. Show must not
    -- consume that switch and let the old Menu callback accept the new address. Wire: QuitDialog 0x005ADF20 ->
    -- MapPane teardown 0x005047F0 keeps its single 0B; changing this ordering changes what the server sees.
    self.connected, self.exiting = true, returningMenu == true
    H:UseOfflineWorld()
    self:Show()
end

function L:IsShown() return screen ~= nil and screen:IsShown() end

-- The session's states that hold a connection, or are opening one (TK.Core.Net.SessionState).
local OPEN_STATES = { Connecting = true, Greeting = true, Hello = true, Menu = true, LoggingIn = true, Accepted = true,
                      Transferring = true, ConnectionLost = true, Reconnecting = true }

--- On start: the login screen, or straight back into the world after a UI reload made there (still connected).
--- A UI reload at the login screen (an interface switch, TK.Interfaces:SwitchTo; the owner's hotfix, 2026-10-06, Astra's
--- review P1 1) finds the session's connection still open: the screen takes it back as it is, its server and its state,
--- and never connects again. WIRE: connecting again would drop the open connection and send "baram" and the version
--- again (GameConnection.Start disconnects first), which 4a's menu never does by itself; a reload must send nothing.
--- After a UI reload with the session's connection open: the server the session is on, without connecting (Client
--- Host's local server as L:StartLocal finds it). In the world too: a Log Out after the reload reads it (s6-modular-g
--- round 17's find). L:Start has loaded the saved play mode first (Client Host's server is not Client's: Astra's
--- re-review, P1 1).
local function resumeServer()
    if L.mode == "offline" then
        local other, _, otherIp, otherLogin = H:GetForeignServer()
        if other == "running" then
            L.localTarget, L.localForeign = L.LocalServer(otherLogin), true
        else
            local _, _, ip, login = H:GetServerState()
            L.localTarget = L.LocalServer(login)
        end
    end
    L.server = L.Target()
end

--- A UI reload restores an open session without sending anything. A closed session waits for Connect, including
--- Local after its server stopped. Wire: MainMenuPane::HandlePacketEvent 0x004F6D80 never reconnects by itself;
--- restoring the menu must send nothing, and changing this changes what the server sees.
function L:Start()
    loadMode() -- the saved play mode first: Local's server is not Client's (Astra's re-review, P1 1)
    local account = __tk:GetSessionAccount()
    if account ~= "" then
        if not screen then buildScreen() end
        resumeServer()
        return self:EnterWorld(account)
    end
    local blocked = H:GetLoginBlock()
    self.blocked = blocked ~= "" and blocked or nil
    local state = H:GetSessionState()
    local closed = state == "Closed" and self.mode ~= "server"
    if closed and self.mode == "offline" and H:GetServerState() ~= "running" and H:GetForeignServer() ~= "running" then
        closed = false -- no server it failed on: Show readies the screen, and Connect starts one (L:StartLocal; Astra's self-review 10-1)
    end
    if not OPEN_STATES[state] and not closed then
        if self.mode == "offline" then
            -- A local server that failed or stopped after it ran (its mode is known): Start, not Show, runs it again. At
            -- the client's start it has never run: Show readies the screen, and Connect starts it.
            local server, mode = H:GetServerState()
            if server == "failed" or (server == "stopped" and mode ~= "") then self.localAsked, self.localFailed = true, true end
        end
        self:Show()
        if self.blocked then setStatus(self.blocked, 1, 0.35, 0.3) end
        return
    end
    resumeServer()
    self.resuming = true
    self:Show()
    self.resuming = nil
    if closed then
        failed()
        if self.blocked then setStatus(self.blocked, 1, 0.35, 0.3) end -- as TK_LOGIN_BLOCKED left it
    else
        self:OnSessionState(state)
    end
end

-- ----- what the session reports -----

local stateText = {
    LoggingIn = "Logging in...", Accepted = "Entering the world...", Transferring = "Entering the world...",
}

-- s6-ui-core (round 33): Leave's look at its press. The session quits by itself (its own fade) and closes about 0.5 s
-- later; the UI hears nothing between, but the dialog model shows it: the connection dialogs have closed while the session
-- is still ConnectionLost (Reconnect opens ReconnectDialog, Cancel the first dialog again, in the same step). Then the
-- pointer hides and the fade starts, as 4a's RequestExit at the press; nothing is sent, and the close stays the session's.
local CONNECTION_DIALOGS = { ConnectionClosedDialog = true, ReconnectDialog = true, CopyWindow = true }
TK.LOST_CONNECTION_DIALOGS = CONNECTION_DIALOGS   -- the dialogs' windows raise these over the cover below

-- Review r32 P2 1: 4a routes the pointer through the modal dialog (EventDispatcher.cpp:264-270), so while the connection
-- is lost nothing under the prompts takes a click (the menu's Quit, Settings, the game's windows): a full-screen cover,
-- under the prompts' windows (raised to FULLSCREEN_DIALOG by the dialogs' window) and over everything else.
local lostCover = CreateFrame("Frame", "TKLostConnectionCover", UIParent)
lostCover:SetFrameStrata("FULLSCREEN_DIALOG")
lostCover:SetFrameLevel(1)
lostCover:SetAllPoints(UIParent)
lostCover:EnableMouse(true)
lostCover:Hide()

local leaveWatch = CreateFrame("Frame", "TKLeaveWatch", UIParent)
leaveWatch:SetSize(1, 1)
leaveWatch:SetScript("OnUpdate", function(self)
    lostCover:SetShown(L.lost == true)
    if not L.lost then
        self.seen, self.closedFrames = nil, 0
        return
    end
    if self.leaving then return end
    local open = false
    for _, v in ipairs(H:GetDialogs() or {}) do
        if CONNECTION_DIALOGS[v.name] then
            open = true
            break
        end
    end
    if open then
        self.seen, self.closedFrames = true, 0
    elseif self.seen and H:GetSessionState() == "ConnectionLost" then
        -- Two frames in a row, so a dialog list a frame behind the state is not taken for the press.
        self.closedFrames = (self.closedFrames or 0) + 1
        if self.closedFrames >= 2 then
            self.leaving = true
            H:BeginExitFade()
        end
    end
end)

--- The session's state changed (TK_SESSION_STATE), or a UI reload took an open connection back (L:Start).
function L:OnSessionState(state)
    -- The change-password dialog belongs to the menu: a session leaving it has closed the session's side already.
    if state ~= "Hello" and state ~= "Menu" then L:HidePassword() end
    -- Wire: TerminalPane::OnTimer 0x0058B470 waits for the socket/greeting; stay at Connect until acceptance below.
    -- Changing this input-to-handshake gate changes what the server sees.
    if state == "Connecting" or state == "Greeting" then L.connecting = true; L:UpdateButtons() end
    -- An interface's own connect screen follows (drawing only): up while this connection starts (not the session's own
    -- reconnect after a loss, which is its ReconnectDialog's), down at the greeting's hand-over to the menu (Hello) or a
    -- loss.
    if state == "Connecting" or state == "Greeting" then
        terminal(not L.lost and state or nil)
    elseif state == "Hello" or state == "Menu" or state == "ConnectionLost" or state == "Reconnecting" then
        terminal(nil)
    end
    -- s6-ui-core (round 32: the gate's reconnect): a connection lost after the greeting stays the session's, in the world
    -- and at the menu. Its ConnectionClosedDialog (D-79, the dialogs' window) decides and nothing reconnects by itself:
    -- Reconnect is the session's own path (ReconnectDialog, D-80: the login server again, and 3 s after its greeting the
    -- menu, "baram" and the version); Leave (OnSecondaryButton: RequestExit) ends the client once the session has closed.
    if state == "ConnectionLost" or state == "Reconnecting" then
        L.lost = true
        lostCover:Show()
        L.connected, L.connecting = false, false
        if screen and screen:IsShown() then
            -- The menu's dialogs close (CloseMainMenuDialogSingletons): the keys are the alert's.
            releaseFields()
            L:UpdateButtons()
            -- s6-protocol round 67 (review r66): with the session's reason (TK_CONNECTION_ENDED came just before), "no
            -- answer to Version" among them; the dialog and its Reconnect stay as they were.
            local why = L.failReason and (": " .. L.failReason) or ""
            setStatus("The connection to the server was lost" .. why .. ".", 1, 0.55, 0.35)
        end
        return
    elseif state == "Closed" and L.lost then
        L.lost = nil
        return L:Exit()
    elseif state == "Hello" and L.lost then
        L.lost = nil
        if TK.GameState:InWorld() then L:BackToMenu() end
    end
    -- s6-modular-g r23: native Classic quit already ended the world in the model. Hand our windows and keys
    -- to the same existing menu path as reconnect; leaving Lua in world kept its bindings and panels alive.
    -- WIRE: QuitDialog 0x005ADF20 -> MapPane::ExitToMenuTeardown 0x005047F0 sends 0B and creates MainMenuPane.
    -- That sender, its queue drain and menu idle order stay in the model. BackToMenu only releases UI ownership;
    -- calling LogOut/ExitToMenu or connecting here would send again and change what the server sees.
    if state == "Menu" and TK.GameState:InWorld() then L:BackToMenu(true) end
    -- In the world the session closes by itself only on an error (TK_SESSION_ERROR follows and logs out with its
    -- message); otherwise the player logged out.
    if TK.GameState:InWorld() or not screen then return end
    if state == "Connecting" or state == "Greeting" then
        setStatus("Contacting server...")
    elseif state == "Hello" or state == "Menu" then
        -- Wire: TerminalPane::HandlePacketEvent 0x0058B130 sends hello/version at Hello; MainMenuPane::HandlePacketEvent
        -- 0x004F6D80 accepts its 00 at Menu. The owner now waits for that acceptance before Login; the session's bytes,
        -- waits and replies are unchanged. Changing this gate changes what the server sees.
        L.connected, L.connecting, L.exiting = state == "Menu" and not L.blocked and not H:GetLoginRefused(), state == "Hello", false
        -- s6-ui-core (round 31; the gate's round 23): our screen is 4a's menu and its Login dialog in one, so the account
        -- field has the keyboard from the greeting, before the version's answer. In 4a the greeting builds MainMenuPane;
        -- choosing Login makes LoginDialogPane, whose SetHoverControl(3) activates the account field (SetFocusedControl(1)
        -- only selects its default OK button; MainMenuPane.cpp:1245-1246); before the greeting there is no account field.
        -- A box the player already types in keeps the keyboard (review r31, P3).
        if state == "Hello" and screen:IsShown() and not L.busy and L.mode ~= "server" and not H:IsTextInputActive() then
            askFocus(screen, screen.account)
        end
        -- A server chosen during Log Out: the old session has sent its 0B and drained to its menu, so now.
        if state == "Menu" and L.serverPending and screen:IsShown() and not L.busy then return L:ServerChanged() end
        L:UpdateButtons()
        if L.blocked then
            setStatus(L.blocked, 1, 0.35, 0.3) -- as TK_LOGIN_BLOCKED left it (s6-play-modes round 10)
        elseif L.versionRefused then
            setStatus("The server refused this client's version.", 1, 0.35, 0.3)
        elseif state == "Hello" then
            setStatus("Contacting server...") -- greeting received, but Connect still waits for acceptance
        else
            setStatus("Connected to " .. serverText(L.server), 0.55, 0.9, 0.55)
        end
        -- --login's automatic login waits for the version's acceptance (Menu), so a refusal cancels it (review r2, 1).
        if state == "Menu" and L.commandLine and screen:IsShown() then
            screen.password:SetText(L.commandLine)
            L.commandLine = nil
            L:Submit()
        end
    elseif state == "Closed" then
        L.exiting = false
        if L.busy then
            setBusy(false)
            L:Error("The connection was closed.")
        end
        failed()
        applyPendingServer()
    end
    local text = stateText[state]
    if text and screen:IsShown() and L.busy then L:Error(text, true) end
end
TK.On("TK_SESSION_STATE", function(_, state) L:OnSessionState(state) end)

TK.On("TK_SESSION_IN_WORLD", function()
    if not L.busy then return end
    H:UseSessionWorld()
    L:EnterWorld(L.account)
end)

local function creating() return create ~= nil and create:IsShown() end

TK.On("TK_LOGIN_REFUSED", function(_, code, message)
    -- Wire: LoginDialogPane::HandlePacketEvent 0x004FAB10 keeps the accepted menu connection after a bad password.
    -- The next 03 uses that connection and its continuing random stream and waits; changing this changes what the server sees.
    -- A credential refusal leaves Login available; only an unaccepted handshake returns to Connect.
    L.connected, L.connecting = true, false
    setBusy(false)
    L.creating = false
    message = message ~= "" and message or ("The server refused the login (" .. tostring(code) .. ").")
    if creating() then return L:CreateMessage(message) end
    L:Error(message)
    -- The original puts the caret in the password for 15 and in the account name for 14, 16-18, 20 and 21; any other
    -- code leaves it where it was (LoginDialogPane::HandlePacketEvent, MainMenuPane.cpp:1279-1293; s6-ui-core round 32,
    -- backlog S-21). The login took it from the fields: the one that had it last gets it back.
    local field = L.REFUSAL_FOCUS[code]
    if field then screen[field]:SetFocus() elseif screen.lastField then screen.lastField:SetFocus() end
    applyPendingServer()
end)

TK.On("TK_LOGIN_BLOCKED", function(_, reason, message)
    -- Plan D22: the session has done what the original does on that path; the screen stays, a creation ends, and no
    -- new attempt is made until the player changes servers. s6-ui-core (round 40, S-15, the head's ruling): a server list
    -- (S 0x56) at the menu leaves the connection open, sending nothing. 4a's MainMenuPane::HandlePacketEvent (0x004F6D80)
    -- takes the list at the menu on the same connection (it opens its Select Server window, which plan D22 leaves out).
    -- Wire: do not disconnect or send anything here for it; a close or an answer is something the server would see
    -- that 4a never does (this handler closed the connection until round 40).
    -- s6-protocol (round 57): also the ban mark (reason MachineMark, plan D6), which comes in the world before the
    -- session's error logs out: 4a crashes there (HandleWriteSystemMscfgDllPacket, 0x00514250) and connects nowhere
    -- again. L.blocked keeps Connect and Login from starting anything (L:UpdateButtons, L:LoginButton) until the player
    -- changes servers. Wire: changing this block changes what the server sees, a connection the original never makes
    -- (s6-gate round 38).
    setBusy(false)
    L.creating = false
    setBlocked(message)
    L.connected, L.connecting = false, false
    L:UpdateButtons()
    if screen then setStatus(message, 1, 0.35, 0.3) end
    if creating() then L:CreateMessage(message) elseif screen then L:Error(message) end
    applyPendingServer()
end)

-- s6-protocol round 66: why the last connection failed or ended (the client log's line has it too), for the status
-- line's failure message; and a server silent for 10 s, said in the status while the client waits on, as the original does.
TK.On("TK_CONNECTION_ENDED", function(_, why, address)
    L.failReason, L.failAddress = why, address
end)

TK.On("TK_CONNECTION_WAITING", function(_, why)
    if not screen or not screen:IsShown() or L.busy or L.lost or TK.GameState:InWorld() then return end
    if L.connected then
        setStatus("Connected to " .. serverText(L.server) .. ", but " .. why .. ".", 1, 0.8, 0.4)
    else
        setStatus("Contacting server... " .. why .. ".", 1, 0.8, 0.4)
    end
end)

-- Alert 157 and its dismissal exit belong only to the original title presentations: 4a MainMenuPane::LegacyMainMenuPacket
-- (0x004F8D00) / 5.33 (0x00459560). Our login screen retains its failure status and retry path.
-- The session already owns the quit and closed-socket sends; changing retry changes the server-visible wire.
TK.On("TK_MENU_TRANSFER_FAILED", function()
    if presentation == nil then return end
    L.menuTransferFailed = true
    L.connected, L.connecting = false, false
    setBusy(false)
    terminal(nil)
    L:UpdateButtons()
    L:Alert(L.OriginalText(157, "You are unable to enter the Nexus right now.\nTry again soon."))
end)

TK.On("TK_SESSION_ERROR", function(_, message)
    if TK.GameState:InWorld() then
        -- s6-ui-core (round 32): a lost connection stays behind its dialog (TK_SESSION_STATE, above).
        if H:IsOnline() and not L.lost then L:LogOut("The connection was lost: " .. tostring(message)) end
        return
    end
    local wasBusy = L.busy
    setBusy(false)
    if L.creating then
        -- Review r32 P2 3: a lost connection keeps the session's creation request (CreateUserDialogPane stays and goes on
        -- taking 02, Session.cs's OnConnectionLost), so the screen keeps it too: Back's cancel-and-disconnect still ends it.
        if not L.lost then L.creating = false end
        if creating() then L:CreateMessage("Could not create the character: " .. tostring(message)) end
    elseif wasBusy and screen then
        L:Error("Could not log in: " .. tostring(message))
    end
    if L.lost then return end -- the dialog's Reconnect, not a retry of ours
    failed()
    applyPendingServer()
end)

-- ----- New Character (the original's New User dialog, CreateUserDialogPane) -----

-- The hair grid's frames per gender (UserHairSelectControlPane; Source-5 systems/character-creation.md), and the
-- colour lists' values, in the original's order.
L.HAIR = {
    [0] = { 0x02, 0x3C, 0x01, 0x08, 0x22, 0x30, 0x50, 0x24, 0x03, 0x53, 0x00, 0x0F, 0x11, 0x18, 0x31, 0x47, 0x33, 0x3B },
    [1] = { 0x21, 0x4A, 0x4E, 0x32, 0x5B, 0x0A, 0x1F, 0x04, 0x07, 0x2D, 0x05, 0x0D, 0x19, 0x36, 0x41, 0x50, 0x34, 0x3A },
}
L.COLOURS = { 0, 3, 5, 7, 1, 9, 8, 10, 11, 12, 13, 20, 26, 24, 21, 29 }

--- The look's values as the preview draws them and packet 0x04 carries them: the face frame, the face colour, the hair
--- frame, the hair colour and the gender (BuildPreviewParams; SendCreateCharacterRequest 0x0052F160 sends the preview's
--- record). WIRE: L:SubmitCreate sends these; changing them changes the 0x04 the server is sent.
function L.CreationArgs(look)
    return look.face - 1, L.COLOURS[look.faceColour], L.HAIR[look.gender][look.hair], L.COLOURS[look.hairColour], look.gender
end

-- s6-ui-core (round 87): an interface's own New User dialog's pictures (its presentation's createDialog), from these
-- tables. Drawing only.

--- The preview of the look facing `facing` (UserCreatePreviewControlPane), in walking frame `frame` and optionally
--- centered for a preview row; a texture key ("" without the packs).
function L.CreationPreview(look, facing, frame, centered)
    local face, faceColour, hair, hairColour, gender = L.CreationArgs(look)
    return (H:GetCreationFigure(face, faceColour, hair, hairColour, gender, facing, frame or 0, centered == true))
end

--- Cell `cell` of the hair grid (1-18, its frame in the look's gender's table) or of the face grid (1-12), in the look's
--- colour (the grids' OnPaint), a texture key ("" without the packs).
function L.CreationCell(look, hair, cell)
    if hair then return (H:GetCreationPart(true, L.HAIR[look.gender][cell], L.COLOURS[look.hairColour])) end
    return (H:GetCreationPart(false, cell - 1, L.COLOURS[look.faceColour]))
end

--- Swatch `i` (1-16) of the hair or face colour list as r, g, b: entry ((value + 16) * 8) mod 256 + 4 of palette slot
--- 14 (HAIR.PAL) or 13 (FACE.PAL) (UserFaceColorSelectListPane::DrawListEntry); black without the packs.
function L.CreationSwatch(hair, i)
    local ok, r, g, b = H:GetPaletteColour(hair and "HAIR.PAL" or "FACE.PAL", (L.COLOURS[i] + 16) * 8 % 256 + 4)
    if ok then return r, g, b end
    return 0, 0, 0
end

-- s6-ui-core (round 32, backlog S-23): the look's preview, as UserCreatePreviewControlPane draws it (s6-characters'
-- GetCreationFigure, the figure at its place in the 82 x 117 cell): facing the viewer (2) as it opens, a step round at
-- each press of the turn button (AdvanceDirection, control 17), drawn again at each change of the look
-- (UpdatePreviewFull). Round 36 (the owner): on the dialog's own box, not on 4a's black cell ("there shouldn't be a black
-- box around the character"). Round 40: at twice its size, so each pixel of the figure is two (1.5 drew them unevenly)
-- and a style's head and body read plainly.
L.PREVIEW_SCALE = 2

-- s6-ui-core (round 37, the owner): "a toggle left right to switch between the modes in the new character page, so you
-- can design your character based on the different modes for characters". The arrows under the preview draw the look in
-- each character style the installed drawing modules offer (the Graphics Styles' modules and their figures option:
-- Modern, Retro's 2026 mix, Mixed and 2003 figure, 3D), starting from the one the Characters category draws in. The
-- preview only: the look, what is sent and when do not change. A style whose module is not installed or fails shows the
-- look Modern, with a note.
local Styles = (function()
    local ok, g = pcall(function() return CS.TK.Modular.Draw.GraphicsStyles end)
    return ok and g or nil
end)()
L.STYLE_NAMES = { ["2d-7x"] = "Modern", ["2d-5x:classic"] = "2026 mix", ["2d-5x:mixed"] = "Mixed", ["2d-5x:whole"] = "2003 figure",
    ["3d-v1"] = "3D" }
L.NOT_IN_STYLE = "Not available here: shown in Modern"
-- s6-ui-core (round 40, the owner: "It seems to all mostly be 1 style?"): for a new character's look several styles draw
-- the same figure, as they do on the map: the 2003 figure and Mixed wherever the hair has a 2003 head (8 of the 18 male
-- hairs, 7 of the 18 female; the two differ in weapons, armour and mounts), and Mixed and the 2026 mix where it has none,
-- which the 2003 figure declines. The note says which, so the arrows plainly work.
L.DECLINED_STYLE = "%s does not draw this look: shown in Modern"
L.SAME_STYLE = "Same as %s for this look"

--- The character styles to preview, { style, name } each, Modern first (none without the modular host).
function L.CharacterStyles()
    local list = {}
    if Styles then
        for style, name in string.gmatch(Styles.CharacterStyles(), "([^=;]+)=([^;]*)") do
            list[#list + 1] = { style = style, name = L.STYLE_NAMES[style] or name }
        end
    end
    return list
end

local function updatePreview()
    local look, pv = create.look, create.preview
    local face, faceColour, hair, hairColour = L.CreationArgs(look)
    local style = create.styles[create.styleIndex]
    local key, inStyle, declined, note
    if style then
        key, inStyle, declined = Styles.CreationPreview(style.style, face, faceColour, hair, hairColour, look.gender, create.facing)
        pv.styleName:SetText(style.name)
        if key ~= "" and not inStyle then
            note = declined and string.format(L.DECLINED_STYLE, style.name) or L.NOT_IN_STYLE
        elseif key ~= "" then
            for i = 1, create.styleIndex - 1 do
                local other, drew = Styles.CreationPreview(create.styles[i].style, face, faceColour, hair, hairColour, look.gender,
                    create.facing)
                if drew and Styles.SamePicture(other, key) then
                    note = string.format(L.SAME_STYLE, create.styles[i].name)
                    break
                end
            end
        end
    else
        key, inStyle = H:GetCreationFigure(face, faceColour, hair, hairColour, look.gender, create.facing), true
    end
    pv.key, pv.inStyle = key, inStyle
    pv.figure:SetShown(key ~= "")
    pv.none:SetShown(key == "")
    pv.note:SetShown(note ~= nil)
    if note then pv.note:SetText(note) end
    if key ~= "" then pv.figure:SetTexture(key) end
end

--- The preview's next (step 1) or previous (-1) character style, round the list.
function L:StepStyle(step)
    local n = #create.styles
    if n == 0 then return end
    create.styleIndex = (create.styleIndex - 1 + step) % n + 1
    updatePreview()
end

-- s6-ui-core (round 62): the shared stepper (W.Stepper), its [<] and [>] where they were; a step round the look's values
local function stepper(parent, label, y, count, key)
    local s
    local function show()
        s:SetValue(tostring(create.look[key]) .. " / " .. count)
        updatePreview()
    end
    s = W.Stepper(parent, label, function(step)
        create.look[key] = (create.look[key] - 1 + step) % count + 1
        show()
    end, { labelWidth = 130, valueWidth = 60, size = 13 })
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", 250, y + 4)
    create.steppers[key] = show
    -- Named for a driver's clicks (gate mode logs them; round 40's pictures of the styles): TKCreateHairColourNext...
    local name = "TKCreate" .. label:gsub(" ", "")
    _G[name .. "Prev"], _G[name .. "Next"] = s.back, s.forward
end

local function buildCreate()
    create = fullScreen("TKCharacterCreate", "New Character")
    create.steppers = {}
    local p = W.Panel(create.content, "TKCreateBox")
    p:SetSize(690, 320)   -- round 40: 20 wider for the preview at twice its size, clear of the steppers
    p:SetPoint("TOP", create.content, "TOP", 0, -136)
    create.box = p
    create.account = W.EditBox(p, 200, 28)
    create.account:SetPoint("TOPLEFT", p, "TOPLEFT", 20, -36)
    create.account:SetMaxLetters(L.MAX_ACCOUNT)
    create.password = W.EditBox(p, 200, 28)
    create.password:SetPoint("TOPLEFT", p, "TOPLEFT", 20, -100)
    create.password:SetPassword(true)
    create.password:SetMaxLetters(L.MAX_CREATE_PASSWORD)
    create.repeatBox = W.EditBox(p, 200, 28)
    create.repeatBox:SetPoint("TOPLEFT", p, "TOPLEFT", 20, -164)
    create.repeatBox:SetPassword(true)
    create.repeatBox:SetMaxLetters(L.MAX_CREATE_PASSWORD)
    for _, l in ipairs({ { "Account Name", -16 }, { "Password", -80 }, { "Repeat Password", -144 } }) do
        local fs = W.Label(p, l[1], 14, W.gold, "LEFT")
        fs:SetPoint("TOPLEFT", p, "TOPLEFT", 20, l[2])
    end

    -- The preview's cell, right of the look's steppers, and its turn button under it.
    local pv = CreateFrame("Frame", "TKCreatePreview", p)
    pv:SetSize(82 * L.PREVIEW_SCALE, 117 * L.PREVIEW_SCALE)
    pv:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -16)
    pv.figure = pv:CreateTexture(nil, "ARTWORK")
    pv.figure:SetAllPoints(pv)
    pv.none = W.Label(pv, "No preview without the art packs.", 11, { 0.6, 0.6, 0.6 })
    pv.none:SetWidth(pv:GetWidth() - 8)
    pv.none:SetWordWrap(true)
    pv.none:SetPoint("CENTER", pv, "CENTER", 0, 0)
    pv.note = W.Label(pv, L.NOT_IN_STYLE, 10, { 0.9, 0.8, 0.55 })
    pv.note:SetWidth(pv:GetWidth() - 8)
    pv.note:SetWordWrap(true)
    pv.note:SetPoint("BOTTOM", pv, "BOTTOM", 0, 4)
    pv.note:Hide()
    -- The style arrows under the cell (round 37), the style's name between them (round 62: the shared stepper).
    local styles = W.Stepper(p, nil, function(step) L:StepStyle(step) end, { valueWidth = 96 })
    styles:SetPoint("TOP", pv, "BOTTOM", 0, -4)
    pv.styleName, pv.stylePrev, pv.styleNext = styles.value, styles.back, styles.forward
    _G.TKCreateStylePrev, _G.TKCreateStyleNext = pv.stylePrev, pv.styleNext   -- named for the gate's driver
    pv.turn = W.Button(p, "Turn", 90, 22, nil, function()
        create.facing = (create.facing + 1) % 4
        updatePreview()
    end)
    pv.turn:SetPoint("TOP", pv, "BOTTOM", 0, -32)
    create.preview = pv
    create.styles, create.styleIndex = {}, 1
    -- A module only the preview drew gives its art back when the screen closes. Hooked, not set: the full screen's own
    -- OnHide (fullScreen: showBackground) must still run, or the login scene stays alive when the world is entered
    -- straight from here (s6-ui-core round 41, Astra's review of 7d91f551; s6-login-scene's row, taken by the UI job).
    create:HookScript("OnHide", function() if Styles then Styles.PreviewDone() end end)

    create.gender = W.Button(p, "", 120, 22, nil, function()
        create.look.gender = 1 - create.look.gender
        create.gender:SetText(create.look.gender == 0 and "Male" or "Female")
        updatePreview()
    end)
    create.gender:SetPoint("TOPLEFT", p, "TOPLEFT", 380, -16)
    _G.TKCreateGender = create.gender   -- named for a driver's clicks, as the steppers
    local g = W.Label(p, "Gender", 13, W.gold, "LEFT")
    g:SetPoint("TOPLEFT", p, "TOPLEFT", 250, -18)
    stepper(p, "Hair", -50, 18, "hair")
    stepper(p, "Hair Colour", -80, 16, "hairColour")
    stepper(p, "Face", -110, 12, "face")
    stepper(p, "Face Colour", -140, 16, "faceColour")
    stepper(p, "Totem", -170, 4, "totem")

    create.ok = W.Button(p, "Create", 140, 30, "red", function() L:SubmitCreate() end)
    create.ok:SetPoint("BOTTOMLEFT", p, "BOTTOM", 10, 16)
    create.back = W.Button(p, "Back", 140, 30, nil, function() L:CancelCreate() end)
    create.back:SetPoint("BOTTOMRIGHT", p, "BOTTOM", -10, 16)
    create.message = W.Label(create.content, "", 13, { 1, 0.35, 0.3 })
    create.message:SetWordWrap(true)
    create.message:SetWidth(520)
    create.message:SetPoint("TOP", p, "BOTTOM", 0, -12)
    -- Enter submits from any box; Tab and Shift+Tab move between them (the host's field order).
    for _, box in ipairs({ create.account, create.password, create.repeatBox }) do
        box:SetScript("OnEnterPressed", function() L:SubmitCreate() end)
    end
    -- Escape on character creation cancels it, as Back, a field with the keyboard included: the original's dialog
    -- takes Escape before its focused control (DialogPane::HandleKeyOrTextEvent 0x0049E6E0).
    TK.Escape:AddWindow(create, function() L:CancelCreate() end)
    create:SetScript("OnUpdate", keepFocus)
    for _, box in ipairs({ create.account, create.password, create.repeatBox }) do
        box:SetScript("OnEscapePressed", function() L:CancelCreate() end)
    end
    ourCreate = create
end

--- The creation's message: on ours its line; an interface's own dialog dims while the request is out (SubmitCreateUser
--- 0x0052ED80's ScreenDimmer, until the 0x02's answers) and says the rest in its alert (its presentation's Message).
function L:CreateMessage(text, progress)
    if create == ourCreate then return showMessage(create.message, text, progress) end
    create.dim:SetShown(progress == true)
    presentation.Message(text, progress)
end

--- The look's gender and steppers as the look is now (each stepper draws the preview again); an interface's own dialog
--- draws it its way.
local function showLook()
    if create.ShowLook then return create.ShowLook() end
    create.gender:SetText(create.look.gender == 0 and "Male" or "Female")
    for _, show in pairs(create.steppers) do show() end
end

function L:ShowCreate()
    -- On the connection: the server the screen is connected to is the one the character is made on. The interface's own
    -- login screen's dialog where it has one (over its menu, which stays), else ours (in place of our screen).
    local own = presentation and presentation.createDialog
    if own then
        create = own
        -- the shared focus handler, as ours has: the field an alert took the keyboard from has it back at the alert's OK
        -- (L:Alert asks it of this dialog), as the account field as it opens
        create:SetScript("OnUpdate", keepFocus)
    else
        if not ourCreate then buildCreate() end
        create = ourCreate
        screen:Hide()
    end
    TK.GameState:Set("charcreate")
    H:OpenCharacterCreation()   -- s6-protocol r51: the dialog's srand(time(0)) and its five draws, on the session's stream
    -- As the original starts: a random hair and face cell (of the first ten), totem and gender; both colours first.
    create.look = { gender = math.random(0, 1), hair = math.random(1, 10), face = math.random(1, 10),
        totem = math.random(1, 4), nation = math.random(0, 1), hairColour = 1, faceColour = 1 }
    create.facing = 2   -- the preview faces the viewer as it opens
    if not own then
        -- The styles to preview, from the one the Characters category draws in (round 37).
        create.styles, create.styleIndex = L.CharacterStyles(), 1
        local current = Styles and Styles.CharacterStyle()
        for i, s in ipairs(create.styles) do
            if s.style == current then create.styleIndex = i end
        end
        local pv = create.preview
        pv.styleName:SetShown(#create.styles > 0)
        pv.stylePrev:SetShown(#create.styles > 1)
        pv.styleNext:SetShown(#create.styles > 1)
        create.message:SetText("")
    else
        create.dim:Hide()
    end
    showLook()
    -- the account ours had typed; the original's fields are empty as it opens (its constructor's TextEditControlPanes)
    create.account:SetText(own and "" or screen.account:GetText())
    create.password:SetText("")
    create.repeatBox:SetText("")
    self.creating = false
    create:Show()
    -- the original's account field first (s6-ui-login)
    askFocus(create, create.account)
end

-- s6-ui-core (round 33, for s6-protocol round 51): the dialog's first look is the session's draws on its own stream
-- (CreateUserDialogPane's srand(time(0)), then the hair and face cells of the first ten, the nation, the totem and the
-- gender draw), raised back as TK_CREATION_LOOK (hair, face, nation, totem, female). Female is the look 4a's draw makes
-- (s6-protocol round 52: a draw of 0 calls SelectFemale, NewUserDialogPane2.cpp:1156-1160). The selected nation is
-- carried as creationNation: 7.5.2's 4a 0x0052F160 sends fixed 0; 5.33's 0x47BA30 sends the choice + 1.
-- Changing it changes what the server sees. Until the session raises it, the look above (Lua's own draws) stands.
TK.On("TK_CREATION_LOOK", function(_, hair, face, nation, totem, female)
    if not (create and create:IsShown() and create.look) then return end
    local look = create.look
    look.hair, look.face, look.totem, look.nation = hair + 1, face + 1, totem + 1, nation
    look.gender = female and 1 or 0
    showLook()
end)

--- Back (or Escape) from New Character ends an outstanding creation's connection and waits for Connect.
--- 4a's CreateUserDialogPane::OnControlCommand (16) only closes the dialog; SubmitCreateUser 0x0052ED80 dims it
--- during its request. Closing an outstanding connection is this UI's existing Back choice, not 4a's cancel path.
--- Wire: no cancellation packet is sent; changing this close changes what the server sees.
function L:CancelCreate()
    if self.creating then
        disconnect()
        self.connected = false
    end
    self.creating = false
    self:Show()
end

--- A refusal's field gets the keyboard: ours at once (its message is a line), an own dialog's at its alert's OK (round
--- 88: askFocus waits for the alert, which keeps the keyboard meanwhile; the original's SetHoverControl reaches the field
--- as the alert closes).
local function focusRefused(box)
    if create == ourCreate then box:SetFocus() else askFocus(create, box) end
end

--- Checks the fields as the original does (a password with a digit, repeated), then creates on the connection.
--- Like the original's, it doesn't check the password's length (15 characters are read): the server's refusal says so
--- (CreateUserDialogPane::SubmitCreateUser 0x0052ED80).
function L:SubmitCreate()
    if self.creating then return end
    local account, password, again = create.account:GetText(), create.password:GetText(), create.repeatBox:GetText()
    create.password:SetText("")
    create.repeatBox:SetText("")
    if not TK.Machine.IsAccountName(account) then
        return self:CreateMessage("An account name has 1 to " .. L.MAX_ACCOUNT .. " letters, digits, '-' or '_'.")
    end
    -- Both refusals put the focus in the password field, as the original's.
    if #password == 0 or not password:find("%d") then
        focusRefused(create.password)
        return self:CreateMessage("The password must contain at least one number.")
    end
    if password ~= again then
        focusRefused(create.password)
        return self:CreateMessage(L.OriginalText(90, L.REPEAT_DIFFERS))
    end
    if not self.connected then return self:CreateMessage("Not connected to the server.") end
    self.creating = true
    self.account = account
    self:CreateMessage("Creating " .. account .. " on " .. self.server.name .. "...", true)
    -- WIRE: 4a's 0x0052F160 sends the look (L.CreationArgs) and totem, with nation 0. 5.33's active dialog sender
    -- 0x47BA30 uses the selected nation + 1. Carry the selection to the shared logic; its protocol chooses the bytes.
    -- Changing these arguments changes what the server sees; the 0x02 then 0x04 order stays the logic's.
    local face, faceColour, hair, hairColour, gender = L.CreationArgs(create.look)
    H:CreateCharacter(account, password, face, hair, faceColour, hairColour, gender, create.look.totem - 1, create.look.nation or 0)
end

-- A refused account's field (HandleCreateUserReply 0x0052F390): these results focus the name, those the password; a
-- refused character (step 2) moves nothing.
L.CREATE_FOCUS = { [3] = "account", [4] = "account", [14] = "account", [16] = "account", [17] = "account",
    [18] = "account", [20] = "account", [21] = "account",
    [5] = "password", [6] = "password", [7] = "password", [8] = "password", [9] = "password", [15] = "password" }

TK.On("TK_CHARACTER_CREATED", function(_, code, message, step)
    if not create or not create:IsShown() then return end
    L.creating = false
    if code == 0 then
        TK.Machine:RememberAccount(L.account)
        L:Show()
        local text = message ~= "" and message or ("The character " .. L.account .. " was created. Log in with it.")
        -- s6-ui-core round 88: an interface's own screen shows it as 4a does. WIRE: HandleCreateUserReply (0x0052F390)
        -- always opens an AlertPane for an accepted character (the server's message, or its own text), and the player's
        -- OK, Enter or Escape closes it through L:CloseAlert, which holds the closing wait (AlertPane::OnControlCommand
        -- 0x004A0580) before the next input; changing it changes when the menu's next packet reaches the server. Ours
        -- says it on its status line, as before.
        if presentation then L:Alert(text) else L:Error(text, true) end
    else
        L:CreateMessage(message ~= "" and message or ("The server refused (" .. tostring(code) .. ")."))
        local field = step == 1 and L.CREATE_FOCUS[code]
        if field then focusRefused(create[field]) end
    end
end)

-- ----- the original's texts (s6-ui-login) -----

-- str.res lines 88 and 90, for a client without the packs.
L.VERSION_REFUSED = "Client outdated.\nPlease download the new client from the Nexus website.\nVisit http://www.nexustk.com"
L.REPEAT_DIFFERS = "Password not confirmed. Please check your password."
-- SubmitPasswordChange's own English text ("password must containt at least 1 number"), spelt right.
L.NEEDS_DIGIT = "The new password must contain at least one number."

--- The original's localized string id (LanguageMan, from the packs), or the fallback.
function L.OriginalText(id, fallback)
    local s = H:OriginalString(id)
    return (s and s ~= "") and s or fallback
end

-- ----- Change Password (the original's ChangePasswordDialogPane, the menu's entry 2; s6-ui-login) -----
--
-- The original's four fields, empty when it opens, the focus on the account: the account name, the current password,
-- the new password and its repetition, the last three masked, none with a limit (the session reads 15 characters of
-- each). OK is enabled once the new password and its repetition hold text, whatever the other two hold
-- (UpdateActionButton 0x004FE490); Enter is OK, and Cancel or Escape closes it and sends nothing. The session checks
-- the form as SubmitPasswordChange (0x004FE560) does: without a digit in the new password, or with a repetition that
-- differs, an alert and the focus on the new password, and nothing is sent; otherwise 0x26 goes out, and the dialog is
-- dimmed until the server's 0x02 (HandlePasswordChangeReply 0x004FEBF0): its message in an alert unless it is empty,
-- and result 0 closes the dialog while any other focuses the field it names. The dialog is modal over the screen.

local pw      -- the dialog in use: ours, or the interface's own login screen's (its presentation's passwordDialog)
local ourPw   -- ours, made once
local PW_BOXES = { "account", "current", "new", "again" }
local PW_FOCUS = { Account = "account", CurrentPassword = "current", NewPassword = "new" }

--- A Change Password dialog's fields and window wired to the logic, ours or an interface's own: Enter is OK and Escape
--- closes it, a change updates OK, Escape over the window closes it, and the field asked for gets the keyboard.
local function wirePassword(f)
    for _, k in ipairs(PW_BOXES) do
        f[k]:SetScript("OnEnterPressed", function() L:SubmitPassword() end)
        f[k]:SetScript("OnEscapePressed", function() L:CloseChangePassword() end)
        f[k]:SetScript("OnTextChanged", function() L:UpdatePasswordOk() end)
    end
    TK.Escape:AddWindow(f, function() L:CloseChangePassword() end)
    f:SetScript("OnUpdate", keepFocus)
end

local function buildPassword()
    -- (ours, the dialog unless the interface's own login screen has its own)
    -- A shade over the whole screen takes every click outside the dialog (modal above the menu, as the original's).
    local f = CreateFrame("Frame", "TKChangePassword", UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetAllPoints(UIParent)
    f:EnableMouse(true)
    local shade = f:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints(f)
    shade:SetColorTexture(0, 0, 0, 0.45)
    local box = W.Panel(f, "TKChangePasswordBox")
    box:SetSize(300, 320)
    box:SetPoint("CENTER", f, "CENTER", 0, 20)
    box:EnableMouse(true)
    local title = W.Label(box, "Change Password", 16, W.gold)
    title:SetPoint("TOP", box, "TOP", 0, -14)
    for i, l in ipairs({ "Account Name", "Current Password", "New Password", "Repeat New Password" }) do
        local fs = W.Label(box, l, 13, W.gold, "LEFT")
        fs:SetPoint("TOPLEFT", box, "TOPLEFT", 20, -44 - (i - 1) * 56)
        local e = W.EditBox(box, 260, 26)
        e:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -4)
        e:SetPassword(i > 1)
        f[PW_BOXES[i]] = e
    end
    f.ok = W.Button(box, "OK", 110, 28, "red", function() L:SubmitPassword() end)
    f.ok:SetPoint("BOTTOMRIGHT", box, "BOTTOM", -8, 16)
    f.cancel = W.Button(box, "Cancel", 110, 28, nil, function() L:CloseChangePassword() end)
    f.cancel:SetPoint("BOTTOMLEFT", box, "BOTTOM", 8, 16)
    -- Named for the gate's driver (s6-gate round 38, 0x26): TKChangePasswordAccount, ...Current, ...New, ...Again, ...OK
    -- and ...Cancel; gate mode logs a named control's place while it shows (core/gatecontrols.lua). Names only.
    for _, k in ipairs(PW_BOXES) do _G["TKChangePassword" .. (k:gsub("^%l", string.upper))] = f[k] end
    _G.TKChangePasswordOK, _G.TKChangePasswordCancel = f.ok, f.cancel
    -- The screen dimmer while the request is out (ScreenDimmer 5): the dialog takes nothing until the answer.
    f.dim = CreateFrame("Frame", "TKChangePasswordDim", box)
    f.dim:SetAllPoints(box)
    f.dim:SetFrameLevel(box:GetFrameLevel() + 10)
    f.dim:EnableMouse(true)
    local dim = f.dim:CreateTexture(nil, "OVERLAY")
    dim:SetAllPoints(f.dim)
    dim:SetColorTexture(0, 0, 0, 0.6)
    local note = W.Label(f.dim, "Changing the password...", 14, W.white)
    note:SetPoint("CENTER", f.dim, "CENTER", 0, 0)
    f.dim:Hide()
    f:Hide()
    wirePassword(f)
    ourPw = f
end

--- An interface's own Change Password dialog (its login screen's passwordDialog, above) wired as ours.
function L.WirePasswordDialog(f) wirePassword(f) end

local function focus(box) askFocus(pw, box) end

local function setWaiting(on)
    pw.waiting = on
    pw.dim:SetShown(on)
    if on then
        pw.focusOn = nil
        for _, k in ipairs(PW_BOXES) do pw[k]:ClearFocus() end
    end
end

--- Change Password: the dialog opens on the session's menu (only while connected, as Login).
function L:OpenChangePassword()
    if not self.connected or self.busy then return self:Error("Not connected to the server yet.") end
    -- the interface's own login screen's dialog where it has one, else ours
    pw = presentation and presentation.passwordDialog
    if not pw then
        if not ourPw then buildPassword() end
        pw = ourPw
    end
    if not H:OpenChangePassword() then return self:Error("Not connected to the server yet.") end
    releaseFields()
    for _, k in ipairs(PW_BOXES) do pw[k]:SetText("") end
    setWaiting(false)
    self:UpdatePasswordOk()
    pw:Show()
    focus(pw.account)
end

function L:UpdatePasswordOk()
    local on = pw.new:GetText() ~= "" and pw.again:GetText() ~= ""
    -- ours greys a disabled OK; an interface's own dialog draws its button's state itself, through its SetEnabled
    -- (5.x's image button shows its wash there, X.Image; Enable/Disable would skip it)
    if pw == ourPw then setEnabled(pw.ok, on) else pw.ok:SetEnabled(on) end
end

--- OK or Enter: the session checks the form and sends 0x26 (TK_PASSWORD_CHECK); dimmed meanwhile, so one request goes.
function L:SubmitPassword()
    if not pw or not pw:IsShown() or pw.waiting or not pw.ok:IsEnabled() then return end
    setWaiting(true)
    if not H:ChangePassword(pw.account:GetText(), pw.current:GetText(), pw.new:GetText(), pw.again:GetText()) then
        self:HidePassword()
        self:Error("Not connected to the server.")
    end
end

--- Cancel or Escape (not while the request is out): the session's dialog closes; nothing is sent.
function L:CloseChangePassword()
    if not pw or not pw:IsShown() or pw.waiting then return end
    H:CloseChangePassword()
    self:HidePassword()
end

--- The dialog goes, its fields emptied.
function L:HidePassword()
    if not pw or not pw:IsShown() then return end
    for _, k in ipairs(PW_BOXES) do pw[k]:SetText("") end
    setWaiting(false)
    pw:Hide()
    if screen:IsShown() then askFocus(screen, screen.account) end   -- the keyboard back to the login box
end

TK.On("TK_PASSWORD_CHECK", function(_, check)
    if not pw or not pw:IsShown() or check == "Sent" then return end
    setWaiting(false)
    if check == "NeedsDigit" or check == "RepeatDiffers" then
        focus(pw.new)   -- once the alert is acknowledged
        L:Alert(check == "NeedsDigit" and L.NEEDS_DIGIT or L.OriginalText(90, L.REPEAT_DIFFERS))
    else
        -- NotOpen: the session's dialog went with its connection.
        L:HidePassword()
        L:Error("Not connected to the server.")
    end
end)

TK.On("TK_PASSWORD_ANSWER", function(_, result, message, field)
    if not pw or not pw:IsShown() then return end
    setWaiting(false)
    if result == 0 then
        L:HidePassword()
    elseif PW_FOCUS[field] then
        focus(pw[PW_FOCUS[field]])
    end
    -- The focus asked for above follows the alert's OK.
    if message ~= "" then L:Alert(message) end
end)

-- ----- the original's alerts (AlertPane; s6-ui-login) -----
--
-- AlertPane (ui/AlertPane.cpp:37) is modal (:129: on the modal list, in front): until its OK it takes every key and
-- click, and OK, Enter or Escape closes it; nothing is sent. A newer one is in front of an older. The login screen's are
-- the change password's and the version refusal's. The field that had the keyboard gives it up meanwhile, and gets it
-- back after (or the field a caller asked for).

--- The newest alert shown (opened: it has just opened), or none left: the interface's own login screen draws it when it
--- has its alerts, else ours.
local function showAlert(opened)
    local text = alerts[#alerts]
    if presentation and presentation.ShowAlert then
        if text then presentation.ShowAlert(text, opened) else presentation.HideAlert() end
        return
    end
    if not text then
        if alert then alert:Hide() end
        return
    end
    alert.text:SetText(text)
    alert.box:SetHeight(math.max(110, alert.text:GetStringHeight() + 80))
    alert:Show()
end

--- OK, Enter or Escape (byKey): the newest alert closes.
function L:CloseAlert(byKey)
    if not table.remove(alerts) then return false end
    -- s6-protocol rounds 42-43: the original's alert slides shut before it closes (five Sleep(24) on its main thread),
    -- after the pressed button's Sleep(133) for a key.
    H:AlertClosed(byKey == true)
    showAlert()
    -- The failed menu transfer's final alert owns the exit only for original title presentations (4a MainMenuPane::LegacyMainMenuPacket
    -- 0x004F8D00 / 5.33 0x00459560). AlertClosed keeps the original close wait; the UI never retries or queues a new handshake.
    if presentation ~= nil and #alerts == 0 and self.menuTransferFailed then self:Exit() end
    return true
end

--- An interface's own dialog took Enter or Escape on one of its buttons (title.lua's byKey): call it in the key, before
--- the button's command. WIRE (s6-ui-core round 92, the final review's P1): the session holds the original's 133 ms
--- pressed button in the key's place (Session.DialogKeyPressed; DialogPane::ActivateDefaultControl 0x0049DE70 /
--- ActivatePendingControl 0x0049DF20), so the command's packet, the menu's timers and later input wait behind it, as the
--- original's sleep holds them. Moving the call after the command, or out of the key, changes that order.
function L:DialogKeyPressed() H:DialogKeyPressed() end

--- An interface's own title opened its login dialog (title.lua's Login entry): call it in the press or key that chose the
--- entry. WIRE (s6-ui-core round 93, head note 30): the session holds the original's 120 ms opening slide in that input's
--- place (Session.LoginDialogOpened; LoginDialogPane 0x004FA7A0's SlideOpenVertical 0x0049EAC0), so the menu's keep-alive
--- and later input due in it wait as the original's do. Ours has no such dialog: its fields show before it connects
--- (decision 2026-10-16-login-dialog-slide-and-modern). Moving the call out of the input changes that order.
function L:LoginDialogOpened() H:LoginDialogOpened() end

function L:Alert(text)
    if not alert and not (presentation and presentation.ShowAlert) then
        alert = CreateFrame("Frame", "TKLoginAlert", UIParent)
        alert:SetFrameStrata("FULLSCREEN_DIALOG")
        alert:SetFrameLevel(120)
        alert:SetAllPoints(UIParent)
        alert:EnableMouse(true)   -- every click behind it is its
        alert.box = W.Panel(alert, "TKLoginAlertBox")
        alert.box:SetWidth(420)
        alert.box:SetPoint("CENTER", alert, "CENTER", 0, 60)
        alert.box:EnableMouse(true)
        alert.text = W.Label(alert.box, "", 14, W.white)
        alert.text:SetWordWrap(true)
        alert.text:SetWidth(380)
        alert.text:SetPoint("TOP", alert.box, "TOP", 0, -20)
        alert.ok = W.Button(alert.box, "OK", 100, 26, "red", function() L:CloseAlert() end)
        alert.ok:SetPoint("BOTTOM", alert.box, "BOTTOM", 0, 14)
        alert:Hide()
    end
    for _, w in ipairs({ { screen, { "account", "password" } }, { create, { "account", "password", "repeatBox" } },
                         { pw, PW_BOXES } }) do
        local win = w[1]
        for _, k in ipairs(win and w[2] or {}) do
            if win[k]:HasFocus() then
                if not win.focusOn then askFocus(win, win[k]) end
                win[k]:ClearFocus()
            end
        end
    end
    alerts[#alerts + 1] = text
    showAlert(true)
end

TK.On("TK_VERSION_REFUSED", function()
    -- S-14: the original's alert, localized string 88 (MainMenuPane::HandlePacketEvent 0x004F6D80). The session is at its
    -- menu on the same connection. Its keep-alive and silence remain the original's; changing them changes the wire.
    if not screen then return end
    -- It comes before the menu's state: --login's automatic login is cancelled, so nothing goes before the alert is
    -- acknowledged (review r2, 1); the owner now returns the button to Connect after a refusal.
    L.versionRefused, L.commandLine, L.connected, L.connecting = true, nil, false, false
    H:SetLoginRefused(true)
    L:UpdateButtons()
    setStatus("The server refused this client's version.", 1, 0.35, 0.3)
    L:Alert(L.OriginalText(88, L.VERSION_REFUSED))
end)

-- ----- Story and History (the original's menu entries 3 and 4: HistoryViewingPane; s6-ui-login) -----
--
-- The full-screen pages of STORY.EPF or HISTORY.EPF from the packs, in the palette NPAL4.PAL (OnPaint), or an interface's
-- own login screen's pages and turn (its presentation's book: 5.x's are 5.33's). The book opens on frame 0 and its first
-- turn goes to frame 3, as AdvancePage (0x004FFD40) does, so frames 1 and 2 are never shown;
-- Enter, Escape, Space or a release of either mouse button turns the page, and on the last page closes the book
-- (HandleKeyOrTextEvent 0x004FFF10, HandlePointerOrMouseEvent 0x004FFFA0). Nothing is sent.

L.BOOK_PALETTE = "NPAL4.PAL"
local book

--- Frame n of a book's picture (its key and size, or nil): the interface's own login screen's pages where it has them,
--- else the packs' in NPAL4.PAL.
local function bookImage(file, n)
    local own = presentation and presentation.book
    if own then return own.Image(file, n) end
    return TK.Art.Image(file, n, L.BOOK_PALETTE)
end

--- How many pages a book has in the packs (0 without them).
function L.BookPages(file)
    local n = 0
    while n < 64 and bookImage(file, n) do n = n + 1 end
    return n
end

local function showPage()
    local key, w, h = bookImage(book.file, book.page)
    local s = math.min(book:GetWidth() / w, book:GetHeight() / h)
    book.picture:SetTexture(key)
    book.picture:SetSize(w * s, h * s)
end

--- The next page; on the last one the book closes.
function L:TurnPage()
    if not book or not book:IsShown() then return false end
    if book.page < book.last then
        local own = presentation and presentation.book
        book.page = own and own.Turn(book.page) or (book.page < 3 and 3 or book.page + 1)
        showPage()
    else
        book:Hide()
        -- The keyboard back to the login field that had it (review r1, 3).
        if screen:IsShown() then askFocus(screen, book.back) end
    end
    return true
end

function L:OpenBook(file)
    if not book then
        book = CreateFrame("Frame", "TKLoginBook", UIParent)
        book:SetFrameStrata("FULLSCREEN")
        book:SetAllPoints(UIParent)
        book:EnableMouse(true)
        local bg = book:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(book)
        bg:SetColorTexture(0, 0, 0, 1)
        book.picture = book:CreateTexture(nil, "ARTWORK")
        book.picture:SetPoint("CENTER", book, "CENTER", 0, 0)
        book:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" or button == "RightButton" then L:TurnPage() end
        end)
        book:Hide()
    end
    local pages = L.BookPages(file)
    if pages == 0 then return end
    -- The keys are the book's now, not a login box's; the one that had them (or was about to) gets them back after.
    book.back = screen.focusOn or screen.lastField or screen.account
    releaseFields()
    book.file, book.page, book.last = file, 0, pages - 1
    book:Show()
    showPage()
end

-- An alert, then the book, take their keys first (bindings.lua's seam), as the original's modal panes do: an alert takes
-- every key and closes on Enter or Escape; the book turns on Enter, Escape and Space.
function TK.LoginKeyHook(key)
    local bare = TK.Util.BareKey(key)
    if alertUp() then
        if bare == "ENTER" or bare == "ESCAPE" then L:CloseAlert(true) end
        return true
    end
    if (bare == "ENTER" or bare == "ESCAPE" or bare == "SPACE") and book and book:IsShown() then return L:TurnPage() end
    -- an interface's own login screen (its menu, its dialog) while no box has the keyboard and no window is over it but
    -- its own Change Password dialog (round 92's final review, P3: that dialog's Enter and Escape with no field focused
    -- are its buttons' keys, as DialogPane's, not the Escape window's close at once)
    local top = presentation and TK.Escape:Topmost()
    if presentation and screen:IsShown() and not H:IsTextInputActive()
        and (not top or top.frame == presentation.passwordDialog) and not W.QuestionShown() then
        return presentation.Key(bare, key)
    end
    return false
end

--- s6-input (round 19): an alert or the book is up and takes every key; a live session then hands every key to the UI
--- first (its routing's UiKeys), so the hook above hears it. s6-ui-core (round 86): an interface's own login screen too,
--- while no box has the keyboard. WIRE: a key the UI takes never reaches the rules; 4a's title takes every key and sends
--- nothing for one (MainMenuPane::HandleKeyOrTextEvent 0x004F6BF0), and changing this changes what a key at the title
--- can send.
function TK.LoginTakesKeys()
    return alertUp() or (book ~= nil and book:IsShown())
        or (presentation ~= nil and screen:IsShown() and not H:IsTextInputActive()) or false
end

-- ----- Quit (the original's menu entry 5, Exit; s6-ui-login) -----

--- MainMenuPane::OpenTerminalPane (0x004F91C0): the connection is reset once what is queued has gone, then the client
--- ends. Nothing is sent (the window's close, by contrast, sends 0B in a game: head note 28). Its sample 0x192 plays
--- as the exit's fade runs (s6-ui-core round 32, backlog S-13).
function L:Quit()
    disconnect()
    self.connected = false
    TK.Game.Sound.PlayEffect(0x192)
    self:Exit()
end

--- The client ends (the menu's Quit, the lost connection's Leave): RequestExit, the fade (TK_EXITING) and then the end.
function L:Exit()
    H:QuitGame()
end

-- RequestExit's fade-out (ScreenPane::BeginFadeOut: 25 frames of 20 ms, the cursor hidden): the screen goes black over
-- everything while the session quits; the host ends the client after it (SessionCalls; s6-ui-core round 32, S-13).
local exitFade
TK.On("TK_EXITING", function()
    if not exitFade then
        exitFade = CreateFrame("Frame", "TKExitFade", UIParent)
        exitFade:SetFrameStrata("TOOLTIP")
        exitFade:SetAllPoints(UIParent)
        exitFade:EnableMouse(true)
        local black = exitFade:CreateTexture(nil, "OVERLAY")
        black:SetAllPoints(exitFade)
        black:SetColorTexture(0, 0, 0, 1)
    end
    local start = GetTime()
    exitFade:SetAlpha(0)
    exitFade:Show()
    exitFade:SetScript("OnUpdate", function(self) self:SetAlpha(math.min(1, (GetTime() - start) / 0.5)) end)
end)

-- Exit Game: the session quits (0B in a game, its fade), then the client ends, as the window's close (head note 28).
TK.GameMenu:AddEntry({ id = "exit", text = "Exit Game", order = 95,
    onClick = function() TK.GameMenu:Close(); H:QuitGame() end })

TK.GameMenu:AddEntry({ id = "logout", text = "Log Out", order = 90,
    onClick = function() TK.GameMenu:Close(); L:LogOut() end })
