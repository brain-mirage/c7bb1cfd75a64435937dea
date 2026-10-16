-- Validation and normalisation of saved settings (review F3).
--
-- A profile or machine file can be valid JSON and still hold the wrong shapes: a number where a table belongs, a
-- string for a boolean, a scale of 99. Nothing from a file reaches the components before it has been through
-- here. Each section is checked on its own; a bad value falls back to its default and is reported, so one bad
-- section never costs the others, and never stops the UI from starting.

local V = {}
TK.Validate = V

local points = {}
for _, p in ipairs(TK.Util.Points) do points[p] = true end

function V.IsPoint(p) return type(p) == "string" and points[p] == true end

local function finite(n) return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge end
V.IsFinite = finite

local function note(problems, path) problems[#problems + 1] = path end

--- Makes value follow the shape of defaults, in place, and returns it (or a fresh copy of defaults if value is
--- not a table at all). Missing keys get their default silently; a present value of the wrong type, a number
--- that is not finite or outside its rule's range, and a string outside its rule's allowed set are replaced
--- (numbers out of range are clamped) and noted in problems as "<path>.<key>". Keys without a default are kept.
---
--- rules[key] = { min = n, max = n } for numbers, or { allowed = { value = true, ... } } for strings.
function V.NormalizeLike(value, defaults, rules, path, problems)
    if type(value) ~= "table" then
        if value ~= nil then note(problems, path) end
        return TK.Util.Copy(defaults)
    end
    rules = rules or {}
    for k, d in pairs(defaults) do
        local v = value[k]
        local here = path .. "." .. tostring(k)
        if v == nil then
            value[k] = TK.Util.Copy(d)
        elseif type(d) == "table" then
            value[k] = V.NormalizeLike(v, d, rules, here, problems)
        elseif type(v) ~= type(d) then
            note(problems, here)
            value[k] = d
        elseif type(d) == "number" then
            local rule = rules[k]
            if not finite(v) then
                note(problems, here)
                value[k] = d
            elseif rule and rule.min and (v < rule.min or v > rule.max) and v ~= rule.stop then -- s6-ui-core (round 60): a slider's end stop
                note(problems, here)
                value[k] = TK.Util.Clamp(v, rule.min, rule.max)
            end
        elseif type(d) == "string" then
            local rule = rules[k]
            if rule and rule.allowed and not rule.allowed[v] then
                note(problems, here)
                value[k] = d
            end
        end
    end
    return value
end

--- A table of positions: key -> { point, relativePoint, x, y }. Bad entries are dropped (the frame goes back to
--- its default place) and noted.
function V.Positions(value, problems)
    if type(value) ~= "table" then
        if value ~= nil then note(problems, "positions") end
        return {}
    end
    local out = {}
    for k, p in pairs(value) do
        local ok = type(k) == "string" and type(p) == "table" and V.IsPoint(p[1])
            and (p[2] == nil or V.IsPoint(p[2])) and finite(p[3] or 0) and finite(p[4] or 0)
            and math.abs(p[3] or 0) <= 20000 and math.abs(p[4] or 0) <= 20000
        if ok then out[k] = { p[1], p[2] or p[1], p[3] or 0, p[4] or 0 }
        else note(problems, "positions." .. tostring(k)) end
    end
    return out
end

--- Key bindings: key name -> command. A command is "CLICK <frame name>" or one of the known command names.
function V.Bindings(value, problems, knownCommands)
    if type(value) ~= "table" then
        if value ~= nil then note(problems, "bindings") end
        return nil
    end
    local out = {}
    for k, c in pairs(value) do
        local ok = type(k) == "string" and #k > 0 and #k <= 40 and V.BindingCommand(c, knownCommands)
        if ok then out[k] = c else note(problems, "bindings." .. tostring(k)) end
    end
    return out
end

--- Whether a binding may name a command: "CLICK <frame>", one of the known commands, or "MACRO <ref>" (s6-macros: a key
--- bound to a macro). s6-modular-g: also what an interface's panel may bring (core/interfaces.lua's AddKeys).
function V.BindingCommand(c, knownCommands)
    if type(c) ~= "string" then return false end
    return c:match("^CLICK [%w_]+$") ~= nil or (knownCommands ~= nil and knownCommands[c] ~= nil)
        or (c:sub(1, 6) == "MACRO " and V.MacroRef(c:sub(7)) == true)
end

--- s6-macros: a reference to one of the player's macros: "account:1" to "account:120", "char:1" to "char:18".
function V.MacroRef(ref)
    if type(ref) ~= "string" then return false end
    local scope, n = ref:match("^(%a+):(%d+)$")
    n = tonumber(n)
    return (scope == "account" and n ~= nil and n >= 1 and n <= 120) or (scope == "char" and n ~= nil and n >= 1 and n <= 18)
end

--- Action slots: "1".."132" -> { kind = "spell"|"item", slot = 1..52 } (a spell with its name), an item by its kind
--- ({ kind = "item", item, name, icon }), or { kind = "macro", id = 0..29 } (one of the
--- character's imported text macros, by its record). 1-120 are the ten bars' buttons, 121-132 the action wheel's.
function V.Actions(value, problems)
    if type(value) ~= "table" then
        if value ~= nil then note(problems, "actions") end
        return nil
    end
    local out = {}
    for k, a in pairs(value) do
        local n = tonumber(k)
        -- the action slot's key ("1" to "132") when k is a whole slot number and a is a table, else false
        local key = n ~= nil and n == math.floor(n) and n >= 1 and n <= 132 and type(a) == "table"
            and tostring(math.floor(n))
        if key and (a.kind == "spell" or a.kind == "item") and type(a.slot) == "number"
            and a.slot == math.floor(a.slot) and a.slot >= 1 and a.slot <= 52 then
            out[key] = { kind = a.kind, slot = math.floor(a.slot),
                -- s6-ui-bars: a spell keeps its name (it follows the spell in the book)
                name = a.kind == "spell" and type(a.name) == "string" and a.name ~= "" and a.name or nil }
        elseif key and a.kind == "item" and type(a.item) == "string" and a.item ~= "" and #a.item <= 255 then
            -- s6-ui-bars: an item by its kind (core/cursor.lua), with the name and picture it had when placed
            out[key] = { kind = "item", item = a.item, name = type(a.name) == "string" and a.name or a.item,
                icon = finite(a.icon) and math.floor(a.icon) or -1 }
        elseif key and a.kind == "macro" and type(a.id) == "number" and a.id == math.floor(a.id) and a.id >= 0
            and a.id <= 29 then
            out[key] = { kind = "macro", id = math.floor(a.id) }
        elseif key and a.kind == "usermacro" and V.MacroRef(a.id) then
            -- s6-macros: one of the player's macros ("account:n", "char:n") on a bar (1-120) or the action wheel (121-132)
            out[key] = { kind = "usermacro", id = a.id }
        else note(problems, "actions." .. tostring(k)) end
    end
    return out
end

--- A list of strings, each checked by accept, at most max long.
function V.StringList(value, problems, path, accept, max)
    if type(value) ~= "table" then
        if value ~= nil then note(problems, path) end
        return {}
    end
    local out = {}
    for i = 1, #value do
        local s = value[i]
        if type(s) == "string" and accept(s) and #out < max then out[#out + 1] = s
        elseif s ~= nil then note(problems, path .. "." .. i) end
    end
    return out
end
