-- The remote protocol's pages (s6-peer round 5; the owner's draft of 2026-10-03, the design's section 6), in the
-- settings list's Plugins tab, nested under Global as the owner drew them (each node's parent; s6-ui-settings' nested
-- menu, core/settings.lua's header):
--
--   Remote-Protocol        the switch (it also needs "Enable unsafe plugins"), the port, Act as a host, the status
--     Command Privileges   a tier for each category: Public, Private or Secure
--     Connections          add and remove; client or host, connected or not; private from a host; pairing for Secure;
--                          the Ignore list (the owner, 2026-10-03: nothing from an ignored player, and the host told)
--     Remote View          round 11 (the owner, 2026-10-04): what this client shares of its view, each off by default
--     Plugins              a title; under it each installed plugin with remote use, with its switches (round 8:
--                          first "Effects on others", the client's own asking while the UI reads it)
--
-- Round 19: the saved category values stay visible with the protocol off, with the shared Needs indicators. The
-- service still applies nothing until both switches are on; these pages let the player configure it first.
-- Kept for this computer in the machine
-- settings: remote = { enabled, port, host, tiers, pluginsOff, categoriesOff, share }. The connections and their
-- pairing codes are the client's own files, reached through TK_RemoteHost (Sandbox/Peer/RemotePage.cs). Listed in the
-- world only (a name connection is stored with the server you are on), as the Peer Channel page was.

local C = TK.GetComponent("peer")

-- s6-peer round 17: 3007, PeerProtocol.DefaultPort (the owner's router forwards 3000-3009 to the dev server's machine,
-- whose server takes 3000-3006). A saved port stays as saved.
local DEFAULT_PORT = 3007
-- The compiled flavour decides whether the optional Secure UI can be loaded.
local publicTest = __tk:IsPublicTest()
local secureRows = not publicTest and require("components.peer.secure") or nil
local TIERS = { { value = "public", text = "Public" }, { value = "private", text = "Private" } }
if not publicTest then TIERS[#TIERS + 1] = { value = "secure", text = "Secure" } end

--- The machine settings' remote table, with its defaults for what is missing or of the wrong type. Round 2's Peer
--- Channel settings (peer = { port, peers }) are carried over once: the port here, the peers to the client's side.
function C:Machine()
    local m = TK.Machine:Get()
    local r = type(m.remote) == "table" and m.remote or {}
    m.remote = r
    if type(m.peer) == "table" then
        if r.port == nil and math.type(m.peer.port) == "integer" then r.port = m.peer.port end
        C.legacyPeers = type(m.peer.peers) == "table" and m.peer.peers or {}
        m.peer = nil
        TK.Machine:MarkDirty()
    end
    if type(r.enabled) ~= "boolean" then r.enabled = false end
    if math.type(r.port) ~= "integer" or r.port < 1 or r.port > 65535 then r.port = DEFAULT_PORT end
    if type(r.host) ~= "boolean" then r.host = false end
    for _, k in ipairs({ "tiers", "pluginsOff", "categoriesOff", "share" }) do
        if type(r[k]) ~= "table" then r[k] = {} end
    end
    return r
end

--- The client's side of the pages, or nil where the protocol does not run (the login screen's own UI, tests).
local function host() return rawget(_G, "TK_RemoteHost") end

local function changed()
    TK.Machine:MarkDirty()
    local S = TK.Settings
    -- The pages' lists (connections, codes, a plugin's switches) follow what changed: the page is built again now.
    if S and S:IsOpen() and S.selected then S:Select(S.selected.id) end
end

-- s6-optimize (round 33; the owner: "dependencies for stuff including any text"): the switch's need on the Global page's
-- switch, its (!), was said only in the page's text. What is allowed stays the service's (PeerService.Allowed: the unsafe
-- switch and this one), as before.
local unsafe = TK.Needs("Global > Enable unsafe plugins", function() return TK.GetComponent("plugins"):Machine().unsafe end)

-- Round 19: every saved row stays usable while off; the existing group seam supplies the two unmet needs separately.
local protocol = TK.Needs("Enable the remote protocol", function() return C:Machine().enabled end)
local function protocolOptions(args)
    return { { type = "group", indent = 0, requires = { unsafe, protocol }, args = args } }
end

--- A line for the player in the chat frame (what an entry could not take, a new code), as the client's own lines.
local function say(text)
    if text and text ~= "" then TK.FireEvent("TK_CHAT_MESSAGE", "local_", "Remote-Protocol: " .. text) end
end

-- ----- Remote-Protocol (design 6.2) -----

local function protocolArgs()
    return {
        { type = "description", name = publicTest and "Plugins may ask other clients for data." or "The remote protocol lets plugins ask other players' clients for data (their "
            .. "place, their health, ...) and lets paired players run commands here, as if typed here. Nothing is sent "
            .. "that nobody asked for, and nothing on the game connection changes." },
        { type = "toggle", name = "Enable the remote protocol", width = "full", requires = { unsafe }, -- s6-optimize (round 33)
          get = function() return C:Machine().enabled end,
          set = function(_, on)
              C:Machine().enabled = on and true or false
              TK.Machine:MarkDirty()
              -- Refresh the existing page's Needs indicators without hiding saved sub-settings.
              if TK.Settings then TK.Settings:RefreshTree() end
          end },
        -- s6-optimize (round 34): the port and host role apply only while the service is allowed to run.
        -- Keep them chosen while off; PeerService.Allowed still gates the service, as before.
        { type = "group", requires = { unsafe, protocol }, args = {
            -- Set on Enter, not as it is typed: each change moves the listener.
            { type = "input", name = "Port (TCP; 3007 by default)",
              set = function(_, text)
                  local n = math.tointeger(tonumber(text))
                  if n and n >= 1 and n <= 65535 then
                      C:Machine().port = n
                      changed()
                  else
                      say("'" .. tostring(text) .. "' is not a port (1 to 65535)")
                  end
              end },
            { type = "description", name = function() return "The port now: " .. C:Machine().port .. "." end },
            { type = "toggle", name = "Act as a host", width = "full",
              get = function() return C:Machine().host end,
              set = function(_, on)
                  C:Machine().host = on and true or false
                  changed()
              end },
            { type = "description", name = publicTest and "Relay Public and Private requests for connected clients." or "As a host, other players' clients connect to you, and you pass their public and "
                .. "private requests on: each update is sent to you once, and you hand it to everyone who asked. Secure "
                .. "requests never go through a host." },
        } },
        { type = "header", name = "Now" },
        { type = "description", name = function() return TK.RemoteStatus or "Off." end },
    }
end

-- ----- Command Privileges (design 6.3) -----

local function privilegesArgs()
    local args = {
        { type = "description", name = publicTest and "Public: anyone. Private: your added connections." or "Who may ask this client for each kind of data. Public: anyone who can reach you. "
            .. "Private: the connections you added yourself. Secure: only players you paired with, directly, never "
            .. "through a host. Requests from a host's own player count as public unless you allow private for that "
            .. "host (Connections)." },
    }
    local h = host()
    if not h then return args end
    local plugin
    for _, c in ipairs(h:Categories()) do
        if c.plugin ~= plugin then
            plugin = c.plugin
            args[#args + 1] = { type = "header", name = plugin == "" and "This client" or plugin }
        end
        local id = c.id
        args[#args + 1] = { type = "select", name = c.title, values = TIERS,
                            get = function()
                                local v = C:Machine().tiers[id] or c.default
                                return publicTest and v == "secure" and "private" or v
                            end,
                            set = function(_, v)
                                C:Machine().tiers[id] = v ~= c.default and v or nil
                                TK.Machine:MarkDirty()
                            end,
                            disabled = c.fixed and function() return true end or nil } -- remote commands stay Secure
    end
    args[#args + 1] = { type = "break" }
    args[#args + 1] = { type = "execute", name = "Put the defaults back", func = function()
        C:Machine().tiers = {}
        changed()
    end }
    return args
end

-- ----- Connections (design 6.4) -----

local function kindText(c)
    local parts = {}
    parts[#parts + 1] = c.kind == "unknown" and "not met yet" or c.kind
    parts[#parts + 1] = c.connected and "connected" or "not connected"
    if c.activeHost then parts[#parts + 1] = "the active host" end
    if c.paired then parts[#parts + 1] = "paired" end
    return table.concat(parts, ", ")
end

local function connectionArgs()
    local args = {
        { type = "description", name = "The players you trust with private requests. Add one by address (another PC: "
            .. "host or host:port) or by character name (on the server you are on: a name is kept with its server). "
            .. "Whether each one is a client or a host shows once it has answered." },
        { type = "input", name = "Add by address (host or host:port)",
          set = function(_, text)
              local h = host()
              if h then say(h:Add(text, false)) end
              changed()
          end },
        { type = "input", name = "Add by character name (this server)",
          set = function(_, text)
              local h = host()
              if h then say(h:Add(text, true)) end
              changed()
          end },
    }
    local h = host()
    if not h then return args end
    local others, ignored = {}, {}
    for _, c in ipairs(h:Connections()) do
        if c.ignored then
            ignored[#ignored + 1] = c
        elseif not c.added then
            others[#others + 1] = c
        else
            local id = c.id
            args[#args + 1] = { type = "header", name = c.byName and (id .. " (this server)") or (c.name ~= "" and (id .. " (" .. c.name .. ")") or id) }
            args[#args + 1] = { type = "description", name = kindText(c) }
            if c.kind == "host" then
                args[#args + 1] = { type = "toggle", name = "Allow private requests from this host's player", width = "full",
                                    get = function() return c.allowPrivate end,
                                    set = function(_, on) h:SetAllowPrivate(id, on) changed() end }
            end
            if secureRows then secureRows(args, c, h, changed, say) end
            args[#args + 1] = { type = "execute", name = "Remove", id = "remove:" .. id,
                                func = function() h:Remove(id) changed() end }
        end
    end
    if #others > 0 then
        args[#args + 1] = { type = "header", name = "Also connected (not in your list)" }
        for _, c in ipairs(others) do
            local id = c.id
            args[#args + 1] = { type = "description", name = id .. (c.name ~= "" and (" (" .. c.name .. ")") or "") .. ": " .. kindText(c) }
            args[#args + 1] = { type = "execute", name = "Add", id = "add:" .. id, func = function() say(h:Add(id, false)) changed() end }
        end
    end
    -- The Ignore list (the owner, 2026-10-03): nothing from these players is accepted or answered, they are not
    -- connected while ignored, and the host is told not to route between them and you (for you only).
    args[#args + 1] = { type = "header", name = "Ignored" }
    args[#args + 1] = { type = "input", name = "Ignore by character name (this server)",
                        set = function(_, text) say(h:Ignore(text, true)) changed() end }
    args[#args + 1] = { type = "input", name = "Ignore by address",
                        set = function(_, text) say(h:Ignore(text, false)) changed() end }
    for _, c in ipairs(ignored) do
        local id = c.id
        args[#args + 1] = { type = "description", name = c.byName and (id .. " (this server)") or id }
        args[#args + 1] = { type = "execute", name = "Stop ignoring", id = "unignore:" .. id,
                            func = function() h:StopIgnoring(id) changed() end }
    end
    args[#args + 1] = { type = "header", name = "Players on the host" }
    args[#args + 1] = { type = "description", name = function() return h:Players() end } -- asked only while shown
    args[#args + 1] = { type = "header", name = "Last refused" }
    args[#args + 1] = { type = "description", name = function() return h:Refusals() end }
    return args
end

-- ----- Remote View (round 11; the owner, 2026-10-04: "private is suppose to have options to send other positional data
-- such as mob location etc. Basically with all options enabled you could remote view another player playing somewhere
-- else in the world") -----

local function viewArgs()
    local args = {
        { type = "description", name = "What this client may share of its view with the players allowed to ask (Private: "
            .. "your connections, as Command Privileges sets it), so that they can watch what you see. Each is off until "
            .. "you turn it on. Only what your client already shows is shared: nothing is asked of the game server for it, "
            .. "and the game connection does not change. Your place itself is Location (Command Privileges)." },
    }
    local h = host()
    if not h then return args end
    for _, c in ipairs(h:Categories()) do
        if c.id:sub(1, 5) == "view-" then
            local id = c.id
            args[#args + 1] = { type = "toggle", name = "Share: " .. c.title, width = "full",
                                get = function() return C:Machine().share[id] == true end,
                                set = function(_, on)
                                    C:Machine().share[id] = on and true or nil
                                    TK.Machine:MarkDirty()
                                end }
        end
    end
    return args
end

-- ----- Plugins > a plugin (design 6.5) -----

local function pluginArgs(p)
    local name = p.name
    -- s6-ui-core (round 54; the owner's rule for every settings page; Astra's review): a category shows its own saved
    -- value; while the plugin's remote protocol is off it has no effect, and its (!) says so (what is allowed is decided
    -- as before, by both).
    local function on(id)
        return function() return not C:Machine().categoriesOff[name .. "|" .. id] end
    end
    local useIt = TK.Needs("Use the remote protocol", function() return not C:Machine().pluginsOff[name] end)
    local function set(id)
        return function(_, v)
            C:Machine().categoriesOff[name .. "|" .. id] = (not v) or nil
            TK.Machine:MarkDirty()
        end
    end
    local args = {
        { type = "toggle", name = "Use the remote protocol", width = "full",
          get = function() return not C:Machine().pluginsOff[name] end,
          set = function(_, v)
              C:Machine().pluginsOff[name] = (not v) or nil
              changed()
          end },
    }
    if #p.asks > 0 then
        args[#args + 1] = { type = "header", name = "Asks for" }
        for _, c in ipairs(p.asks) do
            args[#args + 1] = { type = "toggle", name = c.title, width = "full", get = on(c.id), set = set(c.id),
                                requires = { useIt } }
        end
    end
    if #p.answers > 0 then
        args[#args + 1] = { type = "header", name = "Answers (their tiers: Command Privileges)" }
        for _, c in ipairs(p.answers) do
            args[#args + 1] = { type = "toggle", name = c.title, width = "full", get = on(c.id), set = set(c.id),
                                requires = { useIt } }
        end
    end
    return args
end

function C:SettingsNodes()
    local nodes = { {
        -- s6-ui-settings: under Global (id "plugins"), the owner's tree. Named after the protocol, not the old channel.
        id = "remote", title = "Remote-Protocol", order = self.order, machine = true, category = "plugins", parent = "plugins",
        noReset = true, db = function() return C:Machine() end,
        tabs = { { name = "Remote-Protocol", args = protocolArgs() } },
    } }
    nodes[#nodes + 1] = { id = "remote:privileges", title = "Command Privileges", order = self.order, sub = 1, machine = true,
                          category = "plugins", parent = "remote", noReset = true,
                          db = function() return C:Machine() end,
                          tabs = { { name = "Command Privileges", args = protocolOptions(privilegesArgs()) } } }
    nodes[#nodes + 1] = { id = "remote:connections", title = "Connections", order = self.order, sub = 2, machine = true,
                          category = "plugins", parent = "remote", noReset = true,
                          db = function() return C:Machine() end,
                          tabs = { { name = "Connections", args = protocolOptions(connectionArgs()) } } }
    nodes[#nodes + 1] = { id = "remote:view", title = "Remote View", order = self.order, sub = 3, machine = true,
                          category = "plugins", parent = "remote", noReset = true,
                          db = function() return C:Machine() end,
                          tabs = { { name = "Remote View", args = protocolOptions(viewArgs()) } } }
    local h = host()
    local plugins = h and h:Plugins() or {}
    if #plugins > 0 then
        -- A title only (no tabs): installed plugins with remote use, including their saved settings while off.
        nodes[#nodes + 1] = { id = "remote:plugins", title = "Plugins", order = self.order, sub = 4, category = "plugins",
                              parent = "remote" }
        for i, p in ipairs(plugins) do
            nodes[#nodes + 1] = { id = "remote:plugin:" .. p.name, title = p.title, order = self.order, sub = 4 + i,
                                  machine = true, category = "plugins", parent = "remote:plugins", noReset = true,
                                  db = function() return C:Machine() end, tabs = { { name = p.title, args = protocolOptions(pluginArgs(p)) } } }
        end
    end
    return nodes
end
