-- What belongs to one character (plan 5.14, head note 17), in the player's servers/<server>/<name>/ (C#'s
-- CharacterStore, s6-layout round 7). The one-time import from the original fills these from its .usr files.
--
-- s6-layout round 4: a character is its name on one server. C.ref, taken from the host when the character enters the
-- world (H:CharacterRef), names both; every call that reads or writes the character's files hands it back, and Lua
-- never looks inside it. C.name stays the name, for what is shown.
--
--   hotbars   { version = 1, actions = { ["1"] = { kind = "spell"|"item", slot = 1..52 } | { kind = "macro", id } },
--             spells = { names } }
--             The action bars' slots. A "macro" is one of the original's text macros, by its id in the character's
--             imported macros, which only the host reads (review r4 finding 1). A character's first entry takes the
--             layout profile's bars. s6-ui-bars: an item may be { kind = "item", item, name, icon } (by its kind,
--             core/cursor.lua); spells lists the spells the character has had, so only a new one goes onto a bar.
--   layout    { version = 1, profile = name, interfaces = { [interface] = name } }: the layout profile the character uses.
--             Entering the world switches to it; picking another profile in the world records it. s6-modular-g
--             (interfaces): kept per interface, as the profiles are: profile is Modern's (as every layout from before
--             interfaces), interfaces[id] another interface's.
--
-- Each character's hotbars have a store of their own, which knows whose they are: bars that could not be saved stay
-- pending (and retried) for their character after it leaves, and are its bars if it comes back (review r4 finding 3).
-- Before the world there is no character, and the bars have nothing.

local H = __tk
local U = TK.Util
local V = TK.Validate

local C = { name = nil, ref = nil, stores = {} }
TK.Characters = C

local none = { version = 1, actions = {} }

--- The action slots of the character in the world.
function C:Actions() return (self.hotbars and self.hotbars.data or none).actions end

--- s6-ui-bars: the names of the spells the character in the world has had (a list), or nil before the world.
function C:KnownSpells()
    local data = self.hotbars and self.hotbars.data
    if not data then return nil end
    data.spells = data.spells or {}
    return data.spells
end

function C:MarkDirty() if self.hotbars then self.hotbars:MarkDirty() end end

local function saveLayout()
    if not C.ref then return end
    local layout = C.layout or { version = 1, interfaces = {} }
    -- the default interface's (Modern's) profile is the layout's own, as before interfaces; another's is under its id
    local active = TK.Interfaces.active
    if active == TK.Interfaces:Default() then layout.profile = TK.DB.name else layout.interfaces[active] = TK.DB.name end
    C.layout = layout
    H:CharacterSave(C.ref, "layout", layout)
end

--- s6-interface-5x (round 11): the profile the character in the world uses with an interface (its layout's), or nil
--- outside the world or before it has one.
function C:ProfileFor(interface)
    local layout = self.ref and self.layout
    if not layout then return nil end
    if interface == TK.Interfaces:Default() then return layout.profile end
    return layout.interfaces[interface]
end

--- s6-modular-g: a character's layout as read, its profiles by interface kept (names only). A layout saved before
--- round 11 has them under "themes" (the interfaces' old name).
function C.ReadLayout(stored)
    local layout = { version = 1, interfaces = {} }
    if type(stored) ~= "table" then return layout end
    if type(stored.profile) == "string" then layout.profile = stored.profile end
    local byInterface = stored.interfaces or stored.themes
    for id, name in pairs(type(byInterface) == "table" and byInterface or {}) do
        if type(id) == "string" and type(name) == "string" then layout.interfaces[id] = name end
    end
    return layout
end

--- A store for one character's hotbars; it writes them for that character (on its server), whoever is in the world by then.
local function storeFor(name, ref, data)
    local s = TK.NewStore("The hotbars of " .. name, function(d) return H:CharacterSave(ref, "hotbars", d) end)
    s.data = data
    table.insert(TK.Stores, s)
    return s
end

--- Stops keeping stores that are saved and not in use.
local function prune()
    for key, s in pairs(C.stores) do
        if s ~= C.hotbars and not s.dirty then
            C.stores[key] = nil
            for i, t in ipairs(TK.Stores) do
                if t == s then table.remove(TK.Stores, i) break end
            end
        end
    end
end

--- The character entering the world: its hotbars (still pending ones first) and its layout profile.
function C:Enter(name)
    if self.hotbars then self.hotbars:Flush() end
    self.name = name
    self.ref = H:CharacterRef(name)
    local key = self.ref:lower()
    local pending = self.stores[key]
    if pending and pending.dirty then
        self.hotbars = pending
    else
        local stored = H:CharacterLoad(self.ref, "hotbars")
        local actions = stored and V.Actions(stored.actions, {})
        -- s6-ui-bars: the spells the character has had (only a new one goes onto a bar, as in WoW).
        local spells = stored and V.StringList(stored.spells, {}, "spells", function(s) return s ~= "" end, 1000) or {}
        self.hotbars = storeFor(name, self.ref, { version = 1, actions = actions or U.Copy(TK.DB.profile.actions), spells = spells })
        self.stores[key] = self.hotbars
        if not actions then self.hotbars:MarkDirty() end
    end
    prune()

    self.layout = C.ReadLayout(H:CharacterLoad(self.ref, "layout"))
    local profile = self:ProfileFor(TK.Interfaces.active)
    if profile and profile ~= TK.DB.name and H:ProfileExists(profile) and TK.Interfaces:IsActiveProfile(profile) then
        TK.DB:Switch(profile)
    end
    saveLayout()
    TK.FireEvent("ACTIONBAR_SLOT_CHANGED")
end

-- Leaving: the bars are saved now; if that fails they stay pending for their character (retried, and a reload waits).
TK.On("PLAYER_LEAVING_WORLD", function()
    if C.hotbars then C.hotbars:Flush() end
    C.hotbars = nil
    C.name, C.ref, C.layout = nil, nil, nil
end)

-- A profile picked in the world becomes the character's layout.
TK.On("TK_PROFILE_CHANGED", function()
    if TK.GameState:InWorld() then saveLayout() end
end)
