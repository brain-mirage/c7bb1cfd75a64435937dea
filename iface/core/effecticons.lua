-- s6-ui-core (round 43, effects on others, phase 1; docs/user-related/research/buffs-and-debuffs.md section 5): the
-- effects' logic every interface's displays share: what an effect is called and which kind it is, the player's two name
-- lists, the filters, the order to show them in, the peers' words and the times as text.
--
-- A unit's effects come from __tk:GetUnitBuffs (the world's model: the server's word, the Library's estimates, a peer's
-- share): each has a name, or its candidate spells ("A / B"), or neither ("???"); the time left at the latest and at the
-- earliest (a range; 0 when it may be over), or none; whether that time is the server's word. The arranged rows are
-- debuffs first, then buffs, then unknown ones. The kinds are data (data/effects.lua) and the player's two name lists
-- (below). s6-modular-g (round 16, separation step 7; interface-separation.md 4.1): the icon group that drew them and
-- the pictures are Modern's (interfaces/modern/effecticons.lua and its data/effects.lua). Display only: nothing here is
-- sent.

local data = require("data.effects")

local E = {}
TK.EffectIcons = E

local ORDER = { debuff = 1, buff = 2, unknown = 3 }

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

--- A name as the table keys it: a 3A name's " (Caster)" left out (the test server writes "Description (Caster)").
local function base(name) return trim((name or ""):gsub("%s*%(.*%)$", "")) end
E.Base = base -- s6-modular-g (round 16): for an interface's own data by name (Modern's effect pictures)

local function entryOf(name) return data.effects[base(name)] end

--- The candidates of a row as a list.
function E.Candidates(b)
    local list = {}
    for c in (b.candidates or ""):gmatch("[^/]+") do list[#list + 1] = trim(c) end
    return list
end

--- What the effect is called: its name, its candidates "A / B", or "???".
function E.Label(b)
    if b.name ~= "" then return b.name end
    if (b.candidates or "") ~= "" then return b.candidates end
    return "???"
end

-- ----- the two name lists (the owner, 2026-10-03: "an editable list of buff and debuff names, two lists") -----
-- Kept in the profile's effectLists (buffNames, debuffNames: lists of names and #numbers, in any case; round 44: a list
-- each, edited a row at a time on the settings page; round 45: round 43's text "A, B, #84" is carried over as the profile
-- loads, Effects on Others' C:Migrate). s6-input (round 49, separation step 4b): global, every interface's, so a 7.x or
-- 5.x profile keeps them too (W4); they were Effects on Others' settings, carried over once as the profile loads
-- (Modern's movedSaved, core/db.lua's MoveSaved). A name on a list is that kind wherever it shows:
-- our own effects (the auras), others', the target frame. The filters pick from the same lists. A name on neither keeps
-- the rule before them: this computer's earlier right-click choice (TK.Machine effectOverrides), then data/effects.lua.
-- Nothing is seeded (question 34).

local parsed = {}

--- Round 43's text form, "A, B, #84", as a list (Effects on Others' carry-over, C:Migrate).
local function split(text)
    local list = {}
    for item in (text or ""):gmatch("[^,]+") do
        item = trim(item)
        if item ~= "" then list[#list + 1] = item end
    end
    return list
end

E.Split = split

--- A list ("buff" or "debuff"), as kept in the profile (a list since the profile's carry-over, round 45).
function E.Names(kind)
    local lists = TK.DB.profile and TK.DB.profile.effectLists
    local v = lists and lists[kind .. "Names"]
    return type(v) == "table" and v or {}
end

--- s6-input (round 49): replaces a list ("buff" or "debuff"; the settings page's rows), and says so (E.ListsChanged).
function E.SetNames(kind, list)
    TK.DB.profile.effectLists[kind .. "Names"] = list
    TK.DB:MarkDirty()
    E.ListsChanged()
end

--- A list entry's graphic number ("#84" and "#0x54" alike: 84, 84), or nil for a name. Round 45 (Astra's review of round
--- 44, P2): the one reading of a number, so listing, finding and removing agree on it whatever its spelling.
local function graphicOf(item)
    item = trim(item or "")
    local decimal = item:match("^#%s*(%d+)$")
    if decimal then return tonumber(decimal) end
    local hex = item:match("^#%s*0[xX](%x+)$")
    return hex and tonumber(hex, 16) or nil
end

--- A list's names (lower case, " (Caster)" left out) and graphic numbers ("#84", "#0x54").
local function listOf(kind)
    local list = E.Names(kind)
    local key = table.concat(list, "\n")
    local l = parsed[key]
    if l then return l end
    l = { names = {}, effects = {} }
    for _, item in ipairs(list) do
        item = trim(item)
        local n = graphicOf(item)
        if n then l.effects[n] = true elseif item ~= "" then l.names[base(item):lower()] = true end
    end
    parsed[key] = l
    return l
end

--- A name's kind: its list (the Debuffs list first, if on both), else the earlier rule; nil when nothing says.
function E.NameKind(name)
    local key = base(name):lower()
    if key == "" then return nil end
    if listOf("debuff").names[key] then return "debuff" end
    if listOf("buff").names[key] then return "buff" end
    local m = TK.Machine and TK.Machine:Get()
    local override = m and m.effectOverrides and m.effectOverrides[name]
    if override then return override end
    local e = entryOf(name)
    return e and e.kind or nil
end

--- An effect's kind ("buff" or "debuff") and whether it is unclassified. s6-ui-core (round 43, the owner's two name
--- lists): the Buffs and Debuffs lists first, then this computer's earlier right-click choice, then the table
--- (E.NameKind). s6-modular-g round 15: from Modern's auras (interfaces/modern/panels/auras), as the peer's channel
--- classifies with it too (components/peer); round 16: its icon, the second result before, is Modern's art
--- (interfaces/modern/effecticons.lua's Icon).
function E.Classify(name)
    local kind = E.NameKind(name)
    if kind then return kind, false end
    return "buff", true
end

--- A list without an entry (a name, any case and " (Caster)" aside, or "#84"): a new list.
local function without(list, entry)
    -- Round 45 (Astra's review, P2): a graphic by its number ("#0x54" is "#84"), a name by its text (any case).
    local n, key = graphicOf(entry), base(entry):lower()
    local keep = {}
    for _, item in ipairs(list) do
        local same
        if n then same = graphicOf(item) == n else same = graphicOf(item) == nil and base(item):lower() == key end
        if not same then keep[#keep + 1] = item end
    end
    return keep
end

--- Puts a name (or "#84") on one list ("buff" or "debuff") and takes it off the other: the auras' right-click, and
--- the menu of an icon on another figure (round 44). The lists are replaced, never changed in place.
function E.MoveToList(name, kind)
    local db = TK.DB.profile.effectLists
    local other = kind == "buff" and "debuff" or "buff"
    db[other .. "Names"] = without(E.Names(other), name)
    local mine = without(E.Names(kind), name)
    mine[#mine + 1] = name:match("^#") and trim(name) or base(name)
    db[kind .. "Names"] = mine
    TK.DB:MarkDirty()
end

--- Round 44: takes a name (or "#84") off both lists.
function E.RemoveFromLists(name)
    local db = TK.DB.profile.effectLists
    for _, kind in ipairs({ "buff", "debuff" }) do db[kind .. "Names"] = without(E.Names(kind), name) end
    TK.DB:MarkDirty()
end

--- Round 44: what an effect puts on a list: its name, else each of its candidates, else its graphic's number ("#84");
--- nothing for a "???" of the seconds-left list, which has none.
function E.Entries(b)
    if b.name ~= "" then return { base(b.name) } end
    local c = E.Candidates(b)
    if #c > 0 then return c end
    if (b.effect or 0) > 0 then return { "#" .. b.effect } end
    return {}
end

--- Round 44: the list ("buff" or "debuff") an entry is on, or nil.
function E.ListOf(entry)
    local n = graphicOf(entry)
    for _, kind in ipairs({ "debuff", "buff" }) do
        local l = listOf(kind)
        if n and l.effects[n] or (not n and l.names[base(entry):lower()]) then return kind end
    end
    return nil
end

--- "buff", "debuff" or "unknown": by its name, or by its candidates when they all agree, else by its graphic's number
--- on a list ("#84"), else (round 46) as a connection's client sorted its own effect (a shared row's kind).
function E.Kind(b)
    local kind
    if b.name ~= "" then
        kind = E.NameKind(b.name)
    else
        for _, c in ipairs(E.Candidates(b)) do
            local k = E.NameKind(c) or "unknown"
            if kind == nil then kind = k elseif kind ~= k then kind = "unknown" break end
        end
    end
    if (kind == nil or kind == "unknown") and (b.effect or 0) > 0 then
        if listOf("debuff").effects[b.effect] then return "debuff" end
        if listOf("buff").effects[b.effect] then return "buff" end
    end
    if (kind == nil or kind == "unknown") and (b.kind == "buff" or b.kind == "debuff") then return b.kind end
    return kind or "unknown"
end

local function short(s)
    if s >= 3600 then return math.ceil(s / 3600) .. "h" end
    if s >= 60 then return math.ceil(s / 60) .. "m" end
    return tostring(math.ceil(s))
end

local function long(s)
    s = math.ceil(s)
    if s >= 60 then return string.format("%d:%02d", math.floor(s / 60), s % 60) end
    return s .. " s"
end

--- The time as tiny text under an icon ("47s" as "47", "5m", "~30-60"), or nil when unknown: nothing is shown then
--- (the owner's choice, question 32: "time unknown" is in the tooltip).
function E.ShortTime(b)
    if b.remaining < 0 then return nil end
    local lo, hi = math.max(0, b.remainingMin), b.remaining
    if hi - lo < 1 then return (b.estimate and not b.exact and "~" or "") .. short(hi) end
    return "~" .. short(lo) .. "-" .. short(hi)
end

--- The time as the tooltip says it.
function E.LongTime(b)
    if b.remaining < 0 then return "time unknown" end
    local lo, hi = math.max(0, b.remainingMin), b.remaining
    if hi - lo < 1 then return (b.estimate and not b.exact and "about " or "") .. long(hi) .. " left" end
    -- In minutes when the longest is a minute or more as written (59.6 s is written "1:00").
    local l, h = math.ceil(lo), math.ceil(hi)
    local range = h >= 60 and string.format("%d:%02d-%d:%02d", math.floor(l / 60), l % 60, math.floor(h / 60), h % 60)
        or (l .. "-" .. h .. " s")
    return "about " .. range .. " left" .. (lo < 1 and ", possibly over" or "")
end

--- The seconds-left list's window (the world's Fit): a shared time within it is the same effect's.
local FIT = 3

--- Two names the same, any case and " (Caster)" aside; never for "".
local function same(a, b) return (a or "") ~= "" and base(a):lower() == base(b or ""):lower() end

local taught, taughtTimes, taughtFor = {}, {}, nil

--- The session's side of E.Teach (Session.LearnEffectFromPeer); the tests stand in for it.
function E.Learn(name, graphic, whole) __tk:LearnEffectFromPeer(name, graphic, whole) end

--- Round 47: the Library as it is now (__tk:LibraryIdentity: the session, its server, each switch, Clear or import); the
--- tests stand in for it.
function E.LibraryIdentity() return __tk:LibraryIdentity() end

--- s6-ui-core (round 46, phase 4): a connection's named entry matched to a graphic seen here teaches the Library's trackers
--- (Effects on you: the graphic's name; Effect times on others: its whole time, the row's duration when the peer gives
--- one; Session.LearnEffectFromPeer, under their switches). Names are taught once; the latest whole time is kept per
--- graphic, so a later application may return to an earlier length. Unchanged UI reads do not teach again. Nothing is sent.
--- Round 47 (Astra's review of round 46, P2): "once" is for the Library as it is now. A match the session turned away (its
--- tracker off) or taught to another session's, another server's or a since cleared Library is taught again when that
--- changes (E.LibraryIdentity).
function E.Teach(name, graphic, seconds)
    local identity = E.LibraryIdentity()
    if identity ~= taughtFor then taught, taughtTimes, taughtFor = {}, {}, identity end
    local key, whole = name .. "|" .. graphic, seconds or 0
    if taught[key] and (whole <= 0 or taughtTimes[graphic] == whole) then return end
    taught[key] = true
    if whole > 0 then taughtTimes[graphic] = whole end
    E.Learn(name, graphic, whole)
end

--- Round 47 (Astra's review of round 46, P2): an entry with neither a name nor candidates ("???"), its time the
--- server's: the only kind a peer's row may take by its time alone. An "A / B" entry is for its candidates' rows.
local function bareTimed(b)
    return b.source ~= "peer" and b.exact and b.name == "" and (b.candidates or "") == "" and (b.remaining or -1) >= 0
end

--- s6-ui-core (round 44, phase 4's start; the owner's question 33): a peer's word on the debuffs its own casts put on
--- this creature (s6-peer's TK.PeerCreatureDebuffs: its client's own countdown, the spell by name) in place of what it
--- confirms here: an entry with the same graphic (a lasting graphic, "A / B" or "???") or the same name (our own estimate
--- of that spell). Round 46 (phase 4's rest): for a player (kind "player", by its name), that player's own buffs and
--- debuffs as their client knows them (s6-peer's TK.PeerPlayerEffects, round 9: exact, with the kind their client gives),
--- in place of the same name, or (any kind) one of an "A / B" entry's candidates, or else for a player a "???" whose
--- exact time is the peer's within FIT (the seconds-left list's entries, a timed graphic). Shown as shared, with who said
--- so; where the server gave that entry's time (exact), the time stays the server's; a graphic seen here stays the row's,
--- and when the Library did not name it so, it learns the peer's name for it (E.Teach). A peer's row that confirms nothing
--- is added. Display only: nothing is sent. Without a kind the unit is taken as a creature (round 44's callers).
--- Round 47 (Astra's review of round 46, P2, blocking): the time comes last, after every row's graphic, name and
--- candidates, and takes only a "???" (bareTimed), the closest still free. An unrelated buff of a like time had taken an
--- "A / B" entry first, and the Library learnt its graphic under that buff's name. Round 48 (Astra's re-review): a match by
--- time alone teaches only when the pairing is certain, judged on the set left after the graphic, name and candidate
--- matches, before any time match takes a "???": that row's time fits that one "???" and no other, and that "???"'s time
--- fits no other row (the trackers' own rule: exactly one of each). Judged as the rows were taken, Aegis (50 s) took 85
--- (49 s) and Brine (47 s), left with 87 (45 s) alone, taught it, though 85 fits Brine as well.
function E.WithPeers(rows, id, kind, name)
    local player = kind == "player"
    local peers
    if player then peers = TK.PeerPlayerEffects and TK.PeerPlayerEffects(name or "") or {}
    else peers = TK.PeerCreatureDebuffs and TK.PeerCreatureDebuffs(id) or {} end
    if #peers == 0 then return rows end
    local taken, match, unsure = {}, {}, {}
    local function find(test)
        for i, b in ipairs(rows) do
            if not taken[i] and b.source ~= "peer" and test(b) then return i end
        end
    end
    -- 1. The same graphic, the same name, or one of an "A / B" entry's candidates.
    for k, p in ipairs(peers) do
        match[k] = find(function(b)
            if (p.effect or 0) > 0 and b.effect == p.effect then return true end
            if same(b.name, p.name) then return true end
            for _, c in ipairs(E.Candidates(b)) do
                if same(c, p.name) then return true end
            end
            return false
        end)
        if match[k] then taken[match[k]] = true end
    end
    -- 2. For a player, by its exact time alone: the closest "???" within FIT still free (what is shown). Whether such a
    -- match may teach is judged first, on the fixed set this pass starts from: how many "???" each row's time fits, and
    -- how many rows each "???"'s time fits.
    if player then
        local left, bare = {}, {}
        for k, p in ipairs(peers) do
            if not match[k] and (p.remaining or -1) >= 0 then left[#left + 1] = k end
        end
        for i, b in ipairs(rows) do
            if not taken[i] and bareTimed(b) then bare[#bare + 1] = i end
        end
        local function near(t, u) return math.abs(t - u) <= FIT end
        local fitsOfRow, fitsOfBare = {}, {}
        for _, k in ipairs(left) do
            for _, i in ipairs(bare) do
                if near(rows[i].remaining, peers[k].remaining) then
                    fitsOfRow[k] = (fitsOfRow[k] or 0) + 1
                    fitsOfBare[i] = (fitsOfBare[i] or 0) + 1
                end
            end
        end
        for _, k in ipairs(left) do
            local t, best = peers[k].remaining, nil
            for _, i in ipairs(bare) do
                if not taken[i] and near(rows[i].remaining, t)
                    and (not best or math.abs(rows[i].remaining - t) < math.abs(rows[best].remaining - t)) then
                    best = i
                end
            end
            if best then
                match[k], taken[best] = best, true
                unsure[k] = not (fitsOfRow[k] == 1 and fitsOfBare[best] == 1)
            end
        end
    end
    -- 3. The rows, in the peers' order, then what nothing confirmed.
    local out = {}
    for k, p in ipairs(peers) do
        local remaining = p.remaining or -1
        local row = { name = p.name or "", candidates = "", source = "peer", remaining = remaining, remainingMin = remaining,
                      estimate = not player, exact = player and remaining >= 0, effect = p.effect or 0, from = p.from,
                      kind = p.kind }
        local b = match[k] and rows[match[k]]
        if b then
            if b.exact then row.remaining, row.remainingMin, row.estimate, row.exact = b.remaining, b.remainingMin, false, true end
            -- Round 45 (Astra's review, P2): a peer that gives no graphic keeps the one seen here, so a list entry by
            -- number ("#47") still finds the effect.
            if row.effect == 0 and (b.effect or 0) > 0 then row.effect = b.effect end
            -- A known name may still have a new whole application time. Only the peer's known duration teaches time;
            -- an uncertain match or a countdown without that metadata teaches no duration.
            if (b.effect or 0) > 0 and b.effect ~= 0xFFFF and row.name ~= "" and not unsure[k]
                and (not same(b.name, row.name) or (p.duration or 0) > 0) then
                E.Teach(row.name, b.effect, p.duration or 0)
            end
        end
        out[#out + 1] = row
    end
    for i, b in ipairs(rows) do
        if not taken[i] then out[#out + 1] = b end
    end
    return out
end

--- Where it comes from, as the tooltip says it.
function E.Source(b)
    if b.source == "peer" then return "shared by " .. (b.from and b.from ~= "" and b.from or "that player") end
    if b.estimate then return b.exact and "estimated name, the server's time" or "estimate" end
    return "the server's word"
end

-- ----- the filter basics (the owner: "the option to only show certain debuffs/buffs ... Just the basics") -----

--- The filters' choices, the same for each display and kind; they pick from the two name lists.
E.MODES = {
    { value = "all", text = "Show all" },
    { value = "listed", text = "Only the names on the lists" },
    { value = "debuffs", text = "Only the Debuffs list" },
    { value = "buffs", text = "Only the Buffs list" },
    { value = "unlisted", text = "All but the names on the lists" },
}

--- Whether a list ("buff" or "debuff") names the effect: its name, any of its candidates, or its graphic ("#84", for
--- a "???" one too).
function E.Listed(b, kind)
    local l = listOf(kind)
    if b.effect and b.effect > 0 and l.effects[b.effect] then return true end
    if b.name ~= "" and l.names[base(b.name):lower()] then return true end
    for _, c in ipairs(E.Candidates(b)) do
        if l.names[base(c):lower()] then return true end
    end
    return false
end

--- Whether a filter lets it through (E.MODES).
function E.Passes(b, mode)
    if mode == "debuffs" then return E.Listed(b, "debuff") end
    if mode == "buffs" then return E.Listed(b, "buff") end
    if mode == "listed" then return E.Listed(b, "debuff") or E.Listed(b, "buff") end
    if mode == "unlisted" then return not (E.Listed(b, "debuff") or E.Listed(b, "buff")) end
    return true
end

--- The rows to show, filtered and in order: debuffs, buffs, unknown; the soonest to end first within each.
function E.Arrange(rows, mode, showUnknown)
    local list = {}
    for i = 1, #rows do
        local b = rows[i]
        local kind = E.Kind(b)
        if (showUnknown or E.Label(b) ~= "???") and E.Passes(b, mode) then list[#list + 1] = { row = b, kind = kind } end
    end
    table.sort(list, function(x, y)
        if ORDER[x.kind] ~= ORDER[y.kind] then return ORDER[x.kind] < ORDER[y.kind] end
        local a, c = x.row.remaining < 0 and math.huge or x.row.remaining, y.row.remaining < 0 and math.huge or y.row.remaining
        if a ~= c then return a < c end
        return E.Label(x.row) < E.Label(y.row)
    end)
    return list
end

--- Round 44: the lists changed from a menu: an open settings page shows them, and the frames that sort by them do so
--- again now (round 46: the target frame's row too, not at its next quarter-second refresh). s6-input (round 49,
--- separation step 4b): those frames are an interface's (Modern's auras and target frame), so they listen to
--- TK_EFFECT_LISTS_CHANGED instead of being called here. Drawing only.
function E.ListsChanged()
    if TK.Settings and TK.Settings.selected then TK.SafeCall(TK.Settings.RefreshPage, TK.Settings) end
    TK.FireEvent("TK_EFFECT_LISTS_CHANGED")
end

return E
