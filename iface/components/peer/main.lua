-- The shipped UI's side of the remote protocol (s6-peer round 5; plan D28; the protocol itself is C#: TK-Core/Peer,
-- Sandbox/Peer):
--
--   TK.RemoteSettings()      the Remote-Protocol pages' machine settings (settings.lua), for the client's side
--   TK.RemoteLegacyPeers()   round 2's Peer Channel list, once (then nil), carried over to address connections
--   TK.SetRemoteStatus(s)    the protocol's state, shown on the Remote-Protocol page
--   TK.PeerLocation()        the player's place where the client has it (__tk:GetLocation), else false
--   TK.RemoteData(category)  a built-in category's value from what this interface shows (design 3.4): "health" (vita,
--                            mana and experience, as the player frame shows them) and "effects" (buffs and debuffs as the
--                            auras show them, and the cooldowns as the aether list shows them)
--   TK.PeerCreatureDebuffs(id)  s6-peer (round 8; the owner's question 33): the debuffs the player's connections put on
--                            creature <id> (an object id in view), for effects on others; below
--   TK.PeerPlayerEffects(name)  s6-peer (round 9): the buffs and debuffs player <name> (in view) shared of themselves;
--                            below
--   TK.RemoteEffectKinds()   s6-peer (round 10): the kind each of the player's effects is shown as now, for the client's
--                            change check
--
-- The marks (C_Minimap.SetMark) are the map markers (s6-world-view round 17: core/mapmarkers.lua), drawn
-- on the minimap and the map window: the client sets them through TK.MinimapMarks.Set(id, map, x, y, label, r, g, b
-- [, icon [, persist]]).

local C = TK.GetComponent("peer")
local H = __tk

function TK.RemoteSettings() return C:Machine() end

function TK.RemoteLegacyPeers()
    C:Machine()
    local peers = C.legacyPeers
    C.legacyPeers = nil
    return peers
end

function TK.SetRemoteStatus(text)
    TK.RemoteStatus = text
    local S = TK.Settings
    if S and S:IsOpen() and S.selected and S.selected.id == "remote" then S:RefreshPage() end
end

-- s6-peer round 16: the Connections page's live lines ("Players on the host", "Last refused") are read when the page is
-- drawn, and reading the host's list is what keeps it asked for (TK_RemoteHost:Players ends the request 5 s after the
-- last read). So while that page shows it is drawn again twice a second, as the driver reads the pages: the host's
-- answer shows when it comes, and the list stays asked for while the page is open, and only then.
local connectionsLive = CreateFrame("Frame", nil, UIParent)
connectionsLive:SetScript("OnUpdate", TK.Util.Throttled(0.5, function()
    local S = TK.Settings
    if S and S:IsOpen() and S.selected and S.selected.id == "remote:connections" then S:RefreshPage() end
end))

--- A method of __tk the client may not have; false if it is not there.
local function optional(name)
    local ok, f = pcall(function() return H[name] end)
    return ok and type(f) == "function" and f or false
end

local getLocation

function TK.PeerLocation()
    if getLocation == nil then getLocation = optional("GetLocation") end
    if not getLocation then return false end
    return getLocation(H)
end

--- Seconds left until an absolute GetTime() moment; nil for none (an effect with no end).
local function left(at)
    if not at or at < 0 then return nil end
    return math.max(0, math.floor(at - GetTime() + 0.5))
end

--- The kind an effect is shown as on this interface ("buff" or "debuff"): the effects' classification
--- (TK.EffectIcons.Classify: the Buffs and Debuffs name lists, which a right-click on an aura or an edit on Effects on
--- Others' page changes, then the table).
local function kindOf(name)
    return (TK.EffectIcons.Classify(name))
end

local data = {}

function data.health()
    local ok, hp, hpMax, mp, mpMax = H:GetUnitVitals("player")
    if not ok then return nil end
    -- The experience bar's value and maximum, as the player frame shows them (the server's percent of 100 when it
    -- sends one).
    local xpOk, xp, xpMax = H:GetPlayerXP()
    return { hp = hp, hpMax = hpMax, mp = mp, mpMax = mpMax, xp = xpOk and xp or nil, xpMax = xpOk and xpMax or nil }
end

-- s6-peer (round 11): the last lines said by someone in view (a line with a speaking object: 0x0D), for the view-chat
-- category. Kept here as the chat frame gets them; nothing is sent unless a connection the player shares it with asks.
local KEEP_CHAT = 20
local heard, heardN = {}, 0
TK.On("TK_CHAT_MESSAGE", function(_, channel, text, _, _, speaker)
    if not speaker or speaker == 0 or type(text) ~= "string" then return end
    heardN = heardN + 1
    heard[#heard + 1] = { n = heardN, text = text, speaker = speaker, channel = channel or "" }
    if #heard > KEEP_CHAT then table.remove(heard, 1) end
end)

data["view-chat"] = function() return { lines = heard } end

function data.effects()
    local buffs, debuffs, cooldowns = {}, {}, {}
    for i = 1, H:GetNumEffects() do
        local ok, name, expires, _, duration = H:GetEffect(i)
        if ok then
            local list = kindOf(name) == "debuff" and debuffs or buffs
            -- UI round 46: teach with the announced whole application time, never with its countdown. Unknown/untimed
            -- sources omit duration; this field changes no game timer, request mode or packet on the game connection.
            list[#list + 1] = { name = name, left = left(expires), duration = duration and duration > 0 and duration or nil }
        end
    end
    for i = 1, H:GetNumAethers() do
        local ok, kind, slot, start, duration = H:GetAether(i)
        if ok then
            local name = TK.ActionInfo({ kind = kind, slot = slot })
            if name then cooldowns[#cooldowns + 1] = { name = name, left = left(start + duration) } end
        end
    end
    return { buffs = buffs, debuffs = debuffs, cooldowns = cooldowns }
end

--- s6-peer (round 8): the debuffs the player's connections put on a creature in view, as their clients answered them
--- (the remote protocol's creature-debuffs category, Private), counted down here: a list of { name, remaining (seconds),
--- effect (the graphic their client learned for it, 0 unknown), from (who said so) }, by name; empty when there are
--- none, the protocol is off, or "Effects on others" is switched off on the Remote-Protocol Plugins page. Read only:
--- nothing is sent to the game server or to anyone. How the UI shows them: FOR-s6-ui-core-creature-debuffs.md.
function TK.PeerCreatureDebuffs(id)
    local h = rawget(_G, "TK_RemoteHost")
    if not h or type(id) ~= "number" then return {} end
    return h:CreatureDebuffs(id)
end

--- s6-peer (round 9): the buffs and debuffs a player in view shared of themselves (the remote protocol's effects
--- category, Private: they answer only their connections), as their own interface sorts them, counted down here: a list
--- of { name, kind ("buff" or "debuff"), remaining (seconds, -1 for one with no end), from (the player), duration (the
--- announced whole application time, absent when unknown or untimed) }, buffs first,
--- then by name; empty when they shared none, the protocol is off, or "Effects on others" is switched off for it on the
--- Remote-Protocol Plugins page. Read only: nothing is sent. How the UI shows them: FOR-s6-ui-next-player-effects.md.
function TK.PeerPlayerEffects(name)
    local h = rawget(_G, "TK_RemoteHost")
    if not h or type(name) ~= "string" or name == "" then return {} end
    return h:PlayerEffects(name)
end

--- s6-peer (round 10; Astra's P2 on round 9): the kind each of the player's effects is shown as now, as one string. The
--- client checks it with the effects' own changes, so a reclassification reaches the players subscribed to the effects
--- category: it changes nothing in the world, only how this interface sorts the effect.
function TK.RemoteEffectKinds()
    local parts = {}
    for i = 1, H:GetNumEffects() do
        local ok, name = H:GetEffect(i)
        if ok then parts[#parts + 1] = name .. "=" .. kindOf(name) end
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

function TK.RemoteData(category)
    local f = data[category]
    if not f then return nil end
    local ok, value = pcall(f)
    return ok and value or nil
end
