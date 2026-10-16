-- The build's prebuilt Library (s6-library round 16; the owner, 2026-10-04: "make a folder called prebuild somewhere,
-- when you first connect to a server ask if you want to import the prebuilt library for that protocol IE 5.3 7.5 and you
-- can import it, it should make a copy of it not overrite that. Have a option somewhere intelligent to reset or reload
-- from that cache"). A build ships one per protocol version its server package serves (core\prebuild\<version>\, filled
-- from the build's own server by tools/library-seed, with its maps' cache files since round 26). The first connection to a
-- server asks, once per server, whether to import a copy for the server's version. The Library settings page's Import,
-- "Prebuilt Library" (round 18, the owner: under Import, not a button of its own; library/exchange.lua), opens this file's
-- dialog: it merges into or replaces (round 26, the owner: "maybe change to Merge and Replace the wording is more clear";
-- Reload and Reset until then) the server's Library and map cache from any prebuild the build ships, its own protocol's or another's with a plain warning (the owner,
-- round 16: "You should also be able to import the 7.5 library into 5.3 if you really want to"). The prebuild is only
-- read. The question is a dialog on the login screen only: the connection goes on while it shows, nothing waits for the
-- answer, and nothing is sent for it or for any copy.

local W = TK.UI
local H = __tk
local L = TK.Library

-- asking: the server whose question shows, or waits to; offer: that question's connection (host, port, name, mode) and, once it
-- shows, its Yes, so the same-server question can be asked before it (round 24). waiting: the offers waiting for a host
-- name's lookup, by "host:port", each with the play mode it was made in (round 18).
local P = { asking = nil, offer = nil, waiting = {} }
TK.LibraryPrebuild = P

--- A server's protocol version, as the Servers page sets it (s6-modular's ProtocolHost: 7.5.2 until set).
function P.Version(host, port) return CS.TK.Modular.ProtocolHost.VersionOf(host or "", port or 0) end

--- A Library key's version: that of the saved server with that key, else the default (the local server, one not saved).
function P.VersionOfKey(key)
    for _, s in ipairs(TK.Login and TK.Login.Servers and TK.Login.Servers() or {}) do
        if H:LibraryServerKey(s.host, s.port) == key then return P.Version(s.host, s.port) end
    end
    return P.Version("", 0)
end

--- A copy of the prebuild into a server's Library and map cache ("merge" or "replace"); done(problem) when written ("" for none).
function P.Copy(server, version, mode, done)
    L.Await(H:LibraryFromPrebuild(server, version, mode), function(problem)
        if L.frame and L.frame:IsShown() and L.server == server then L:Refresh() end
        if done then done(problem) end
    end)
end

--- Round 17 (Astra's P3 on round 16): the question is a line or two, as the shared Yes/No dialog's fixed size leaves
--- about three lines above its buttons (its other users unchanged).
local QUESTION_HEIGHT = 40

--- Round 24 (Astra's pass 4): the longest the offer waits for a new address's table list (a server that sends none still
--- gets the offer).
local TABLES_WAIT = 5

--- The login screen's connection to a server (login.lua, once it has begun connecting): the first time, when a prebuilt
--- Library ships for the server's version, asks whether to import a copy into the server's Library. Yes imports (as
--- Merge: what the Library learned before stays, and the maps play brought); No imports nothing. Either answer is kept, so it is asked once per
--- server.
function P:Offer(host, port, name)
    -- Round 24 (Astra's pass 5): the login screen offering another server drops an offer still waiting for its table list
    -- (below), so it never shows over that server; its retries of the same server keep it. Round 27: a fresh offer after a
    -- mode change also retires the old unseen one, even before its await has checked the mode.
    local pending = self.offer
    if pending and not pending.yes and (pending.mode ~= (TK.Login and TK.Login.mode) or pending.host ~= host or pending.port ~= port) then
        self:Withdraw(pending.host .. ":" .. pending.port)
    end
    local server = H:LibraryServerKey(host, port)
    if server == nil then
        -- Round 17 (Astra's P2 on round 16): a host name still being looked up has no Library key yet. The question waits
        -- for it (TK.Library.Await, each frame) while the connection goes on unchanged, then is asked if the login screen
        -- still targets that server.
        -- Round 18 (Astra's lines on round 17): one wait per host and port, however often the login screen retries it or
        -- moves between servers meanwhile; and a play-mode change while it waits drops it (login.lua's SetMode keeps
        -- TK.Login.server while Client Host starts or in Dedicated Server, so the target alone would still match).
        local wait, mode = host .. ":" .. tostring(port), TK.Login and TK.Login.mode
        if self.waiting[wait] then return end
        self.waiting[wait] = true
        L.Await(function() return H:LibraryServerKey(host, port) end, function()
            self.waiting[wait] = nil
            local target = TK.Login and TK.Login.server
            if TK.Login.mode == mode and target and target.host == host and target.port == port then self:Offer(host, port, name) end
        end)
        return
    end
    if server == "" or self.asking == server then return end
    local version = P.Version(host, port)
    if not H:LibraryPrebuildToOffer(server, version) then return end
    self.asking = server
    local o = { host = host, port = port, name = name, mode = TK.Login and TK.Login.mode }
    self.offer = o
    -- Round 24 (QA's head note; Astra's pass 4 on its first fix): the same-server question comes first, since after its Yes
    -- the offer for a "new" server does not apply. Its evidence, a new address's table list, comes at the menu moments
    -- after the connect: the offer waits for it unseen (TABLES_WAIT at most). The same-server watch takes it while it waits
    -- when its question comes (Withdraw); else that is asked once more (Poll), and the offer is made, once no other question
    -- is open (Astra's pass 5: one the player opened meanwhile is not replaced).
    if not H:LibrarySameServerWaits(host, port) then return self:Make(o, server, version) end
    local deadline = GetTime() + TABLES_WAIT
    -- Round 27: like the DNS wait, an unseen table-list offer belongs to its requesting mode and target. Withdraw it
    -- before checking another confirmation, so it retires even while that question owns the dialog. A retired callback
    -- cannot clear or replace a fresh offer. Already-shown offers keep their existing answer behavior.
    -- This is only a Library UI wait: Login:Connect's TerminalPane::OnTimer 0x0058B470 connection bytes/order/waits stay
    -- unchanged. Changing those would change what the server sees; this offer and its cancellation send nothing.
    local function owned()
        if self.offer ~= o then return false end
        local target = TK.Login and TK.Login.server
        if (TK.Login and TK.Login.mode) ~= o.mode or not target or target.host ~= host or target.port ~= port then
            self:Withdraw(host .. ":" .. port)
            return false
        end
        return true
    end
    TK.Await(function()
        if not owned() then return true end
        if W.confirm and W.confirm:IsShown() then return nil end
        return (not H:LibrarySameServerWaits(host, port) or GetTime() > deadline) or nil
    end, function()
        if not owned() then return end -- retired or taken by the same-server question
        if TK.LibrarySameServer then TK.LibrarySameServer:Poll() end
        if self.offer == o then self:Make(o, server, version) end
    end)
end

--- Makes the offer o (P:Offer's, for server and version) in the shared Yes/No dialog.
function P:Make(o, server, version)
    local function answered()
        self.asking, self.offer = nil, nil
        H:LibraryPrebuildAnswered(server)
    end
    o.yes = function()
        answered()
        P.Copy(server, version, "merge", function(problem)
            if problem ~= "" then TK.Notify("The prebuilt Library was not imported: " .. problem) end
        end)
    end
    W.Confirm("Import a copy of the prebuilt " .. version .. " Library for " .. (o.name or server) .. "?", o.yes, answered)
    -- A server name too long for two lines is "this server" (the login screen shows which).
    if W.confirm.text:GetStringHeight() > QUESTION_HEIGHT then
        W.confirm.text:SetText("Import a copy of the prebuilt " .. version .. " Library for this server?")
    end
end

--- Round 24 (QA's head note): the offer, while it is the question showing, else nil.
function P:Showing()
    local o, c = self.offer, W.confirm
    return o and o.yes and c and c:IsShown() and c.onYes == o.yes and o or nil
end

--- Takes the offer for address ("host:port", the same-server question's; sameserver.lua) down unanswered, showing or
--- waiting for the table list, and returns it (its host, port and name, to offer again after a No); else nil.
function P:Withdraw(address)
    local o = self.offer
    if not o or o.host .. ":" .. o.port ~= address or (o.yes and not self:Showing()) then return nil end
    if o.yes then W.confirm:Hide() end
    self.asking, self.offer = nil, nil
    return o
end

-- ----- Import's "Prebuilt Library" -----

--- The dialog on a server (the settings page's Import): the prebuilt Libraries the build ships (its own protocol's chosen
--- first), Merge, Replace (asked once more) and Close.
function P:OpenDialog(server)
    if not server or server == "" then return end -- the server is still being looked up
    local d = self.dialog
    if not d then
        d = TK.LibraryExchange.Dialog("TKLibraryPrebuild", "Prebuilt Library", 330)
        d.version = W.Dropdown(d, "Prebuilt Library", {}, 320, function(v) P:Choose(v) end)
        d.version:SetPoint("TOPLEFT", d, "TOPLEFT", 20, -128)
        d.message:SetPoint("TOPLEFT", d, "TOPLEFT", 20, -180)
        d.status = W.Label(d, "", 12, W.white, "LEFT")
        d.status:SetWordWrap(true)
        d.status:SetWidth(480)
        d.status:SetPoint("TOPLEFT", d, "TOPLEFT", 20, -240)
        d.replace = W.Button(d, "Replace", 140, 26, "red", function() P:Run("replace") end)
        d.replace:SetPoint("BOTTOM", d, "BOTTOM", 0, 16)
        d.merge = W.Button(d, "Merge", 100, 26, "red", function() P:Run("merge") end)
        d.merge:SetPoint("RIGHT", d.replace, "LEFT", -8, 0)
        d.close = W.Button(d, "Close", 100, 26, nil, function() d:Hide() end)
        d.close:SetPoint("LEFT", d.replace, "RIGHT", 8, 0)
        self.dialog = d
    end
    d.server, d.own = server, P.VersionOfKey(server)
    local values, own = {}, nil
    for v in string.gmatch(H:LibraryPrebuildVersions(), "[^;]+") do
        if v == d.own then own = v end
        values[#values + 1] = { value = v, text = v .. (v == d.own and "  (this server's protocol)" or "  (another protocol)") }
    end
    d.version:SetValues(values)
    -- Round 18 (the owner: no wordy text): what the buttons do, in a line each.
    d.text:SetText("Into: " .. server .. "\nMerge keeps what you learned in play. Replace overwrites it; your characters stay.")
    d.status:SetText("")
    P:Choose(own or (values[1] and values[1].value))
    d:Show()
end

--- A prebuild chosen in the dialog: a plain warning when it is another protocol's.
function P:Choose(version)
    local d = self.dialog
    d.chosen = version
    d.version:SetValue(version)
    d.replace:SetText("Replace")
    d.message:SetText(version ~= d.own and ("For " .. tostring(version) .. " servers; this server speaks " .. d.own
        .. ". Its maps, items and shops may not match.") or "")
end

--- Merge, or Replace once confirmed, from the prebuild chosen: a copy into the dialog's server's Library and map cache.
function P:Run(mode)
    local d = self.dialog
    if not d.chosen then return end
    if mode == "replace" and d.replace:GetText() ~= "Confirm Replace" then
        d.replace:SetText("Confirm Replace")
        return
    end
    d.replace:SetText("Replace")
    local server, version = d.server, d.chosen
    d.status:SetText((mode == "replace" and "Replacing" or "Merging") .. " from the " .. version .. " prebuilt Library...")
    P.Copy(server, version, mode, function(problem)
        if not (d:IsShown() and d.server == server) then return end
        d.status:SetText(problem == "" and ((mode == "replace" and "Replaced" or "Merged") .. " from the " .. version .. " prebuilt Library.")
            or ("Not copied: " .. problem))
    end)
end

return P
