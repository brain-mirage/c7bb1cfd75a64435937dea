-- Settings profiles. A profile is one JSON file under the player's config/profiles/ (written by C#'s ProfileStore):
--
--   global     the lock state and Button Lock (per profile, as in Bartender)
--   components one table per component, filled from its defaults
--   positions  frame key -> { point, relativePoint, x, y } relative to UIParent
--   bindings   key -> command, e.g. ["CTRL-1"] = "CLICK TKHotkey13" (the original's hotkey carriers: core/game/hotkeys.lua)
--   secondaryKeys  key -> true: the keys in their command's second slot (s6-ui-bars; the others are primary)
--   actions    action slot (as a string) -> { kind = "spell"|"item", slot = 1..52 }: the bars a character starts with
--              on its first entry; its own are in its hotbars (TK.Characters)
--
-- Settings that belong to the computer (UI scale, grid, snapping) are in TK.Machine instead.
--
-- Loading never loses data (review F2, F3):
--   * a file that cannot be read is moved aside by C# (<name>.json.corrupt-<time>) before defaults are used;
--   * a readable file with invalid sections is copied aside (<name>.json.invalid-<time>), then each section is
--     repaired on its own and the rest kept;
--   * the user is told either way.
-- Saving follows TK.NewStore's rules (review F10): changes are kept until a write succeeds.

local H = __tk
local U = TK.Util
local V = TK.Validate

local DB = { name = "Default" }
TK.DB = DB

-- s6-modular-g (interfaces, phase 2): the profile is saved without the other interfaces' panels that are off
-- (TK.Interfaces:Trimmed).
DB.store = TK.NewStore("The profile", function(data) return H:ProfileSave(DB.name, TK.Interfaces:Trimmed(data)) end)
table.insert(TK.Stores, DB.store)

DB.globalDefaults = {
    locked = true,
    buttonLock = false,
    -- s6-ui-settings: the settings window's list tab and the row last open in each ("" none yet), for its next opening.
    settingsTab = "interface",
    settingsRows = { general = "", interface = "", plugins = "" },
    -- s6-ui-settings (nested settings menus): the list's entries closed with their + / - button, id -> true.
    settingsCollapsed = {},
}

--- Defaults other modules add to: DB.defaultBindings[key] = command, DB.defaultActions["1"] = {...}.
DB.defaultBindings = {}
DB.defaultActions = {}

--- Commands other than "CLICK <frame>" that a binding may name (the character window, the bag, ...).
DB.knownCommands = {}

function DB:NewProfile()
    return {
        version = 2,
        global = U.Copy(self.globalDefaults),
        components = {},
        positions = {},
        bindings = U.Copy(self.defaultBindings),
        actions = U.Copy(self.defaultActions),
        defaultsGiven = self:DefaultCommands(),
    }
end

--- The commands the default bindings name, as a set.
function DB:DefaultCommands()
    local set = {}
    for _, command in pairs(self.defaultBindings) do set[command] = true end
    return set
end

--- The commands that came after profiles began to note what they were given (rounds 17 and 18), with the logic's own
--- commands (bindingsNewIn2, core/bindings.lua): a profile without the note was given every other default when it was
--- made. Core's own here; a component or panel adds its own beside its default (the list is read at profile load,
--- after they load): Original Commands' MUSIC, the action wheel's two.
DB.NEWER_COMMANDS = { "SCREENSHOT", "SCREENSHOTBMP" }

function DB:GivenBeforeTheMark()
    local given = self:DefaultCommands()
    for _, command in ipairs(self.NEWER_COMMANDS) do given[command] = nil end
    for command in pairs(self.bindingsNewIn2 or {}) do given[command] = nil end
    return given
end

--- A command added since the profile was made gets its default keys once, those still free, when it has none (an older
--- profile has no screenshot, movement or action wheel keys); a key the player unbinds afterwards stays unbound.
function DB:GiveNewDefaults(bindings, given)
    local has = {}
    for _, command in pairs(bindings) do has[command] = true end
    for key, command in pairs(self.defaultBindings) do
        if not given[command] and not has[command] and bindings[key] == nil then
            bindings[key] = command
            self.migrated = true
        end
    end
    return self:DefaultCommands()
end

--- The table holding a dotted profile path's last key, and that key; nil when a table on the way is missing (make: made).
local function holder(t, path, make)
    local keys = {}
    for k in path:gmatch("[^.]+") do keys[#keys + 1] = k end
    for i = 1, #keys - 1 do
        if type(t[keys[i]]) ~= "table" then
            if not make then return nil end
            t[keys[i]] = {}
        end
        t = t[keys[i]]
    end
    return t, keys[#keys]
end

--- s6-input (round 49; interface-separation.md 5.13): saved values an interface's components held that are now global,
--- moved once for every profile, whichever interface it is for: each installed interface's movedSaved, { ["<old path>"] =
--- "<new path>" } (dotted paths in the profile). The old value is read once, then dropped; a value already at the new path
--- is kept. A profile something moved in is saved as it loads.
function DB:MoveSaved(out)
    for _, interface in ipairs(TK.Interfaces.list) do
        for from, to in pairs(interface.movedSaved or {}) do
            local old, key = holder(out, from)
            if old and old[key] ~= nil then
                local new, newKey = holder(out, to, true)
                if new[newKey] == nil then new[newKey] = old[key] end
                old[key] = nil
                self.migrated = true
            end
        end
    end
end

--- s6-modular-g (round 19, the separation's step 8; interface-separation.md 7.1): the commands each installed interface
--- renamed (its renamedCommands, { ["<old>"] = "<new>" }: Modern's 30 hotkeys, from its bar buttons to the game layer's
--- carriers), every interface's, naming none.
function DB:Renamed()
    local out = {}
    for _, interface in ipairs(TK.Interfaces.list) do
        for old, new in pairs(interface.renamedCommands or {}) do out[old] = new end
    end
    return out
end

--- Renames the commands a map holds as values (key -> command), in place (Classic's snapshot of the bindings its preset
--- replaced, its Migrate). A profile something was renamed in is saved as it loads.
function DB:RenameCommands(map)
    local renamed = self:Renamed()
    for key, command in pairs(map) do
        if renamed[command] then
            map[key] = renamed[command]
            self.migrated = true
        end
    end
end

--- The renames carried over once, before any default is given (GiveNewDefaults, here and in a component's Migrate): in
--- the profile's bindings, in its note of the defaults given (an old command noted marks its new name, so a hotkey the
--- player deliberately unbound stays unbound) and in the computer's global keys (TK.Bindings:Globals, by command). A
--- renamed command is never saved under its old name again. Wire: the hotkeys keep their keys, and the keys their
--- input path (a CLICK binding: core/game/hotkeys.lua); losing one changes what a key sends.
function DB:CarryRenamed(p, given)
    local renamed = self:Renamed()
    if type(p.bindings) == "table" then self:RenameCommands(p.bindings) end
    for old, new in pairs(renamed) do
        if given[old] then given[new], given[old] = true, nil end
    end
    local m = TK.Machine.store.data
    local globals = type(m) == "table" and type(m.globalBindings) == "table" and m.globalBindings or {}
    for old, new in pairs(renamed) do
        if globals[old] ~= nil then
            if globals[new] == nil then globals[new] = globals[old] end
            globals[old] = nil
            TK.Machine:MarkDirty()
        end
    end
end

--- Checks and repairs a profile section by section. Returns the repaired profile and the list of problems.
function DB:Normalize(p)
    local problems = {}
    if type(p) ~= "table" then
        problems[1] = "profile"
        p = {}
    end
    local out = { version = 2 }
    if p.version ~= nil and type(p.version) ~= "number" then problems[#problems + 1] = "version" end

    -- Only the per-profile keys (globalDefaults') stay in global; older profiles also held the machine settings.
    local g = p.global
    if g ~= nil and type(g) ~= "table" then
        problems[#problems + 1] = "global"
        g = nil
    end
    local kept = {}
    for k in pairs(self.globalDefaults) do kept[k] = g and g[k] end
    out.global = V.NormalizeLike(kept, self.globalDefaults, nil, "global", problems)

    local comps = p.components
    if comps ~= nil and type(comps) ~= "table" then
        problems[#problems + 1] = "components"
        comps = nil
    end
    out.components = {}
    for name, value in pairs(comps or {}) do out.components[name] = value end
    -- Commands added since the profile was made get their default keys once, where free (version 2, s6-input: the
    -- logic's own commands, walking included, which an imported or version-1 profile lacked); below, and in a
    -- component's own saved bindings (its Migrate).
    local given = type(p.defaultsGiven) == "table" and p.defaultsGiven or self:GivenBeforeTheMark()
    self:CarryRenamed(p, given) -- s6-modular-g (round 19, step 8): first, before any default is given
    for _, c in ipairs(TK.Components.list) do
        -- s6-ui-core (round 45, Astra's review of round 44, P1): a component's saved table in an older form is carried
        -- over first (C:Migrate(saved, given), in place, true when it changed something), since the check against the
        -- defaults below replaces a value whose type changed (round 43's name lists were text, round 44's are lists) and
        -- would lose it. A carried-over profile is saved (Load).
        local saved = out.components[c.name]
        if type(saved) == "table" and c.Migrate then
            local ok, changed = pcall(c.Migrate, c, saved, given)
            if not ok then H:LogWarning("profile: " .. c.name .. "'s carry-over failed: " .. tostring(changed))
            elseif changed then self.migrated = true end
        end
        out.components[c.name] = V.NormalizeLike(out.components[c.name], c.defaults or {}, c:ValueRules(),
            "components." .. c.name, problems)
    end
    -- s6-input (round 49, separation step 4b): the effect name lists, every interface's (core/effecticons.lua), with
    -- what an interface's component kept of them before, moved here after its own carry-over above (DB:MoveSaved).
    out.effectLists = p.effectLists
    self:MoveSaved(out)
    out.effectLists = V.NormalizeLike(out.effectLists, { buffNames = {}, debuffNames = {} }, nil, "effectLists", problems)

    out.positions = V.Positions(p.positions, problems)
    out.bindings = V.Bindings(p.bindings, problems, self.knownCommands) or U.Copy(self.defaultBindings)
    out.defaultsGiven = self:GiveNewDefaults(out.bindings, given)
    -- s6-ui-bars: the keys in their command's second slot (core/bindings.lua); a mark on an unbound key is dropped.
    out.secondaryKeys = {}
    for k, v in pairs(type(p.secondaryKeys) == "table" and p.secondaryKeys or {}) do
        if v == true and out.bindings[k] then out.secondaryKeys[k] = true end
    end
    out.actions = V.Actions(p.actions, problems) or U.Copy(self.defaultActions)
    -- s6-modular-g (interfaces, phase 2; core/interfaces.lua): the interface the profile is for (none: Modern, as every
    -- profile from before interfaces), the keys each panel turned on added, and the looks chosen in it. A profile saved
    -- before round 11 has the interface under "theme" (the interfaces' old name).
    local interface = p.interface or p.theme
    out.interface = type(interface) == "string" and interface or nil
    out.panelKeys = TK.Interfaces.NormalizePanelKeys(p.panelKeys, out.bindings)
    out.parkedBindings = TK.Interfaces.NormalizeParked(p.parkedBindings, self.knownCommands) -- the owner's hotfix, 2026-10-06
    out.looks = TK.Interfaces.NormalizeLooks(p.looks)
    out.unused = TK.Interfaces.NormalizeUnused(p.unused)
    out.migrated = TK.Interfaces.NormalizeMigrated(p.migrated) -- s6-interface-5x (round 12): its interface's carry-overs
    return out, problems
end

local function listed(problems)
    local shown = {}
    for i = 1, math.min(#problems, 6) do shown[i] = problems[i] end
    local s = table.concat(shown, ", ")
    if #problems > 6 then s = s .. " and " .. (#problems - 6) .. " more" end
    return s
end

--- Loads a profile. A damaged or invalid file is kept aside before anything replaces it.
function DB:Load(name)
    if not H:ProfileIsValidName(name) then name = "Default" end
    local p, status = H:ProfileLoad(name)
    self.name = name
    -- s6-interface-5x (round 11): a profile its interface's Reset marked (TK.Interfaces:Reset, for an interface not in
    -- use then) loads as new, as a first start in its interface makes it; its file is written over at the save below.
    local resets = TK.Machine:Get().resetProfiles
    if resets[name] then
        resets[name] = nil
        TK.Machine:MarkDirty()
        p = nil
    end
    local fresh = p == nil
    if status:sub(1, 12) == "quarantined|" then
        local file = status:match("^quarantined|([^|]*)|")
        TK.Popup("Profile '" .. name .. "' could not be read. The file was kept as " .. tostring(file)
            .. " and the default settings are used.", "Profile recovered")
    elseif status:sub(1, 11) == "unreadable|" then
        TK.Popup("Profile '" .. name .. "' could not be read or moved aside. The defaults are used, and the file "
            .. "is left alone until it can be read.", "Profile not loaded")
        self.readOnly = true
    end
    local data, problems = self:Normalize(p or self:NewProfile())
    if not fresh and #problems > 0 then
        local copy = H:ProfileBackup(name, "invalid")
        TK.Popup("Some settings in profile '" .. name .. "' were invalid and were reset: " .. listed(problems)
            .. ". The original file is kept as " .. tostring(copy) .. ".", "Profile repaired")
        H:LogWarning("profile '" .. name .. "': invalid " .. table.concat(problems, ", "))
    end
    self.store.data = data
    TK.Interfaces:Untrim() -- s6-modular-g (interfaces, phase 2): the panels the saved profile left out, off
    if fresh then TK.Interfaces:ApplyDefaults() end -- s6-modular-g: a new profile as the active interface makes it
    TK.Interfaces:Migrate() -- s6-interface-5x (round 12): the interface's one-off carry-overs, saved below
    H:ProfileSetCurrent(name)
    if fresh or #problems > 0 or self.migrated then
        if not self.readOnly then self.store:Save() end
    end
    self.migrated = nil
end

-- The profile lives in the store; DB.profile reads it.
setmetatable(DB, { __index = function(_, k) if k == "profile" then return DB.store.data end end })

function DB:Save() return self.store:Save() end

--- Saves soon; many changes in a row (a slider being dragged) become one write.
function DB:MarkDirty() self.store:MarkDirty() end

function DB:Component(name)
    return self.profile.components[name]
end

function DB:Global() return self.profile.global end

-- ----- profile management, as AceDB's profile options -----

function DB:List()
    local t = H:ProfileList()
    local names = {}
    for i = 1, #t do names[i] = t[i] end
    return names
end

--- The current profile's unsaved changes must be on disk before another profile replaces them.
local function flushOrRefuse(action)
    if DB.store:Flush() then return true end
    TK.Popup("The current profile could not be saved, so it was not " .. action .. ". Its changes are kept.",
        "Profile not changed")
    return false
end

function DB:Switch(name)
    if name == self.name then return true end
    if not flushOrRefuse("switched") then return false end
    self:Load(name)
    TK.Components:ReapplyAll()
    return true
end

function DB:Create(name)
    if not H:ProfileIsValidName(name) then return false, "Use letters, digits, spaces, '-', '_' or '.'" end
    if H:ProfileExists(name) then return false, "A profile with that name already exists" end
    if not flushOrRefuse("switched") then return false, "The current profile could not be saved" end
    self.name = name
    TK.Machine:Get().resetProfiles[name] = nil -- s6-interface-5x (round 11): a new profile carries no old Reset mark
    self.store.data = self:Normalize(self:NewProfile())
    TK.Interfaces:ApplyDefaults() -- s6-modular-g (Astra's r8 review, 2): the active interface's defaults
    H:ProfileSetCurrent(name)
    self.store:Save()
    TK.Components:ReapplyAll()
    return true
end

--- Copies another profile's settings into the current one.
function DB:CopyFrom(name)
    local p, status = H:ProfileLoad(name)
    if not p then
        if status:sub(1, 12) == "quarantined|" then
            TK.Popup("Profile '" .. name .. "' could not be read and was kept as "
                .. tostring(status:match("^quarantined|([^|]*)|")) .. "; nothing was copied.", "Profile not copied")
        end
        return false
    end
    self.store.data = self:Normalize(p)
    TK.Interfaces:Untrim() -- s6-modular-g (interfaces, phase 2)
    TK.Interfaces:Migrate() -- s6-interface-5x (round 12)
    self.store:Save()
    TK.Components:ReapplyAll()
    return true
end

--- Resets the current profile to the defaults.
function DB:Reset()
    self.store.data = self:Normalize(self:NewProfile())
    TK.Interfaces:ApplyDefaults() -- s6-modular-g (Astra's r8 review, 2): the active interface's defaults
    self.store:Save()
    TK.Components:ReapplyAll()
end

--- s6-interface-5x (round 11, W12; interface-separation.md, 5.17): runs fn with the store holding a first profile of the
--- active interface, made as DB:Reset makes one (a new profile, then the interface's defaults), and returns what fn
--- returns; the live profile is put back with its dirty mark as it was, so nothing is saved, applied or fired. The
--- settings window's reset reads its defaults here, so they are the active interface's, not the components' own.
function DB:InFirstProfile(fn)
    local store = self.store
    local live, dirty, dirtyAt, migrated = store.data, store.dirty, store.dirtyAt, self.migrated
    store.data = self:Normalize(self:NewProfile())
    local ok, result = pcall(function()
        TK.Interfaces:ApplyDefaults()
        return fn()
    end)
    store.data, store.dirty, store.dirtyAt, self.migrated = live, dirty, dirtyAt, migrated
    if not ok then error(result, 0) end
    return result
end

function DB:Delete(name)
    if name == self.name then return false end
    -- s6-interface-5x (round 11): an interface's Reset mark goes with its profile, so a new profile of that name is not one
    local resets = TK.Machine:Get().resetProfiles
    if resets[name] then
        resets[name] = nil
        TK.Machine:MarkDirty()
    end
    return H:ProfileDelete(name)
end
