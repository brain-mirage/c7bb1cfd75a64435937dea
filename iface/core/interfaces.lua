-- s6-modular-g (interfaces, phase 2; docs/development/interfaces.md, section 1 "Profiles", "Mixing", "When a
-- change applies"): the interface registry. Every installed interface is a folder with its interface.lua (the host lists them under
-- the Lua folder's interfaces folder, AppPaths.InterfacesRoot); the active interface is a computer setting, read when the UI
-- loads: a switch (T:SwitchTo: the Interface tab's Active, the Next Interface key) saves it and takes effect at once (the
-- owner's hotfix, 2026-10-06; round 13: a profile switch in place, no UI reload); the connection stays and nothing is sent.
--
-- Each interface has its own profile (the profile records its interface), made from the interface's defaults on its first use: its
-- own panels on, every other interface's off, its keys where free, its looks. A panel of another interface turned on adds its
-- keys where they are free and records them; turned off it removes exactly those, and its commands' other keys are parked
-- (Mixing; the owner's hotfix of 2026-10-06: core/bindings.lua B:Park). Our tools (the settings window, edit mode, the game
-- menu and its menu button...) are no interface's and are in every one.
--
-- s6-interface-5x (round 13, the separation's step 11; the owner's answer to Q52): only the panels in use are loaded
-- (T:InUse; core/components.lua loads and unloads their code).
--
-- It draws nothing and sends nothing: the keys it adds are bindings to commands, which run what they run in any interface.

local H = __tk

local T = { list = {}, byId = {}, panelsOf = {}, switches = {} }
TK.Interfaces = T

--- s6-protocol rounds 68-69 (the owner's screenshot, 2026-10-04: a built client offered "5.x (test stand-in)"): whether
--- an interface is offered. A test's stand-in says testOnly = true in its manifest (the table it returns, read as Lua
--- reads it), and is offered only from the tests' own folder (fromTests: H:InterfaceFromTests), never from the
--- installed ones a build carries, where one was once copied by hand.
function T.Offered(interface, fromTests)
    return interface.testOnly ~= true or fromTests == true
end

--- Loads every installed interface's interface.lua (once, at the start), the default interface (Modern) first.
function T:Load()
    self.list, self.byId = {}, {}
    for _, id in ipairs(H:InterfaceList() or {}) do
        local ok, interface = xpcall(require, debug.traceback, "interfaces." .. id .. ".interface")
        if ok and type(interface) == "table" and not T.Offered(interface, H:InterfaceFromTests(id)) then
            H:Log("interface " .. id .. ": a test's own (testOnly), not offered outside the tests")
        elseif ok and type(interface) == "table" and type(interface.panels) == "table" then
            interface.id = id
            for _, panel in ipairs(interface.panels) do panel.interface = id end
            self.byId[id] = interface
            self.list[#self.list + 1] = interface
        else
            H:LogError("interface " .. id .. ": " .. tostring(interface))
        end
    end
    table.sort(self.list, function(a, b)
        if (a.default == true) ~= (b.default == true) then return a.default == true end
        return a.id < b.id
    end)
    -- s6-optimize (round 28): the panels found once, in the list's order (the lists are fixed from here on): each
    -- component's (T:PanelsOf: T:InUse and T:Dormant, asked for every bound key through TK.Bindings:Inert, and the
    -- components' sync) and each switch's (node id, then key: T:Blocks and T:SettingChanged, asked on every setting change)
    self.panelsOf, self.switches = {}, {}
    for _, interface in ipairs(self.list) do
        for _, panel in ipairs(interface.panels) do
            if panel.component then
                local of = self.panelsOf[panel.component] or {}
                of[#of + 1] = panel
                self.panelsOf[panel.component] = of
            end
            if panel.node and panel.switch then
                local node = self.switches[panel.node] or {}
                local at = node[panel.switch] or {}
                at[#at + 1] = panel
                node[panel.switch], self.switches[panel.node] = at, node
            end
        end
    end
    local chosen = TK.Machine:Get().interface
    self.active = self.byId[chosen] and chosen or self:Default()
end

function T:Get(id) return self.byId[id] end

--- s6-interface-5x (round 11; interface-separation.md, 5.16): the installed interfaces in the order the player sees them
--- (the Interface list's headings): by each manifest's order (Modern 1, 7.x 2, 5.x 3), then by id. The registry's own
--- list keeps its order (the panels' components load in it).
function T:InOrder()
    local out = {}
    for i, interface in ipairs(self.list) do out[i] = interface end
    table.sort(out, function(a, b)
        local x, y = a.order or math.huge, b.order or math.huge
        if x ~= y then return x < y end
        return a.id < b.id
    end)
    return out
end

--- The active interface: the one chosen when the UI was loaded, or switched to since (T:SwitchNow).
function T:Active() return self.byId[self.active] or self.byId[self:Default()] end

--- s6-input (round 49, separation step 4b; interface-separation.md 5.13, agreed with s6-interface-5x): the default
--- interface's id, the one its manifest declares (default = true: Modern's), for the fallbacks that named it.
--- s6-interface-5x (round 15, step 9): every fallback in core/ that named Modern asks it.
function T:Default()
    for _, interface in ipairs(self.list) do if interface.default then return interface.id end end
end

--- The interface chosen for the next start (the Interfaces page): the default one until the player chooses.
function T:Chosen() return self.byId[TK.Machine:Get().interface] and TK.Machine:Get().interface or self:Default() end

--- Chooses the interface for the next start: saved at once in the computer's settings; nothing else changes now.
function T:Choose(id)
    if not self.byId[id] then return end
    TK.Machine:Get().interface = id
    TK.Machine:MarkDirty()
end

-- ----- switching at once (the owner's hotfix, 2026-10-06: "There shouldnt need to be a restart"; "you are suppose to be
-- able to keybind the interfaces and switch between them with a hotkey"; s6-interface-5x round 13's hotfix: in place;
-- interface-separation.md 5.16, the decision 2026-10-05-interface-switch-as-a-profile-switch) -----

--- Switches to an interface at once, with no restart and no UI reload: a profile switch (T:SwitchNow) on the frame
--- after the input that asked for it (the Active box, the keys), once no mouse press is held on a frame and no key whose
--- binding acts on its release (round 14: TK.Bindings:HeldForRelease). False when it
--- cannot: not installed, already in use, or a login under way (Astra's re-review of the head's hotfix, P1 2: the player
--- switches once in the world or back at the screen).
---
--- byKey: the switch was made by a key (Next Interface, Switch to <interface>). Bindings are per profile, so the keys that
--- switch interfaces follow the switch (interface-separation.md 5.16, "Its key follows the switch"; Astra's review of the
--- head's hotfix, P1 2): each is bound in the profile the switch ends in, where its key is free there and its command has
--- no key (T:BindCarried: at once in the world, where the switch loads the character's own profile; from the login screen
--- once the character enters and its own is chosen). Bind Next Interface once and it cycles every interface. A switch
--- from the Interface tab carries nothing.
function T:SwitchTo(id, byKey)
    if not self.byId[id] or id == self.active then return false end
    local state = TK.GameState:Get()
    if (TK.Login and TK.Login.busy) or not (state == "world" or state == "login") then
        TK.Notify("Switch interfaces once the login has finished.", "interfaceswitch")
        return false
    end
    self.pending = { id = id, byKey = byKey }
    return true
end

--- Whether a command switches interfaces (components/interfaces/main.lua registers them).
function T.SwitchCommand(command)
    return command == "INTERFACENEXT" or command:sub(1, 10) == "INTERFACE_"
end

-- Wire: the switch waits for the frame after its input, for no press held on a frame and for no held key whose binding
-- acts on its release (round 14: the action wheel's pick, which may run a control's action, TK.Actions:RunFrame), so a
-- press and its release reach the same control (4a gives a captured press's release to the pane that captured it:
-- EventDispatcher::DispatchEvent 0x004A7130; a held list's release ends its 20 ms tick, as LuaHost.Tick's reload waits);
-- running it inside a press would change what the release sends. Changing this changes what the server sees.
local switcher = CreateFrame("Frame", nil, UIParent)
switcher:SetScript("OnUpdate", function()
    local p = T.pending
    if not p or H:AnyFramePressed() or TK.Bindings:HeldForRelease() then return end
    T.pending = nil
    T:SwitchNow(p.id, p.byKey)
end)

--- The switch itself, in the UI's tick (T:SwitchTo): the profile in use saved (nothing switches when it cannot be), the
--- views' windows closed as the player closes them, the interface set and saved for the next start, its profile loaded
--- (in the world the character's for it, else the one last used with it, made from its defaults on first use), the
--- switching keys carried by a switch made by key and the global keys laid over it (T:Loaded), then the whole profile
--- applied again: TK.Components:ReapplyAll loads the panels now in use and unloads the others (step 11;
--- interface-separation.md 5.18). Wire: nothing is sent. It runs outside any input, where nothing can send (a page's
--- request needs one, plan 5.9; the dialogs' calls theirs); a close sends nothing; the session, its timers and the C#
--- state are untouched; afterwards the next inputs act as after a start in that interface, with what the player can
--- change by hand (windows closed, the profile's keys and settings). Changing this changes what the server sees.
function T:SwitchNow(id, byKey)
    if not self.byId[id] or id == self.active then return end
    local carry
    if byKey then
        carry = {}
        for key, command in pairs(TK.Bindings:Map()) do
            -- (a global one needs no carrying: it is in every interface already, TK.Bindings:ApplyGlobals)
            if T.SwitchCommand(command) and not TK.Bindings:IsGlobal(command) then carry[#carry + 1] = { key = key, command = command } end
        end
    end
    if not TK.FlushAll() then
        TK.Notify("Settings could not be saved: not switched.", "interfaceswitch")
        return
    end
    TK.Game.Views.CloseWindows()
    self:Choose(id)
    TK.Machine:Get().interfaceKeysCarried = carry
    self.active = id
    local name = TK.GameState:InWorld() and TK.Characters:ProfileFor(id) or nil
    if not (name and H:ProfileExists(name) and self:IsActiveProfile(name)) then name = self:ProfileName() end
    TK.DB:Load(name)
    self:Loaded()
    if TK.GameState:InWorld() then self:BindCarried() end -- the character's own profile is final here (no entering)
    TK.Panels:View(id)
    TK.Components:ReapplyAll()
    -- (Q147's highlight of 7.x's open tab after the switch is the 7.x screen's own, on this event: its main.lua)
    TK.FireEvent("TK_INTERFACE_CHANGED", id)
    TK.Notify("Interface: " .. (self:Active().name or id), "interfaceswitch")
end

--- The Next Interface key's press (the owner: "if I bind it to 7 and im on modern it goes to 7x and enables it, disable
--- the other, press again it enables 5x disables 7x and again enables modern"): the next interface in the tab's order
--- after the active one, switched at once (T:SwitchTo).
function T:Next(byKey)
    local list = self:InOrder()
    for i, interface in ipairs(list) do
        if interface.id == self.active then return self:SwitchTo(list[i % #list + 1].id, byKey) end
    end
    return list[1] ~= nil and self:SwitchTo(list[1].id, byKey)
end

--- The other interfaces' panels as components: { name, dir } manifests for the component registry, for each panel whose
--- interface gives its code (panel.dir under the interface's folder). Modern's moved panels carry their manifest.json and
--- come with the components (LuaHost.ComponentList: interfaces/modern/panels/<component>/).
function T:PanelManifests()
    local out, seen = {}, {}
    for _, interface in ipairs(self.list) do
        for i, panel in ipairs(interface.panels) do
            -- several panels may share one component (7.x's decoration pieces: its screen)
            if panel.dir and not seen[panel.component] then
                seen[panel.component] = { name = panel.component, title = panel.name, order = 500 + i,
                                          dir = "interfaces/" .. interface.id .. "/" .. panel.dir, commands = {} }
                out[#out + 1] = seen[panel.component]
            end
            -- s6-interface-5x (round 13, step 11): its commands, declared before the profile (5.18), from any of its
            -- panels' entries ({ name, text, keys, newer }, as a manifest.json's commands)
            if panel.dir then
                for _, command in ipairs(panel.commands or {}) do table.insert(seen[panel.component].commands, command) end
            end
        end
    end
    return out
end

-- ----- which panels are in use (s6-interface-5x, round 13, the separation's step 11; interface-separation.md 5.18) -----

--- Every installed interface's panels whose component is name, in the list's order: T:Load's index (s6-optimize round
--- 29: it is asked for every component at each sync and for every bound key through T:Dormant); callers only read it.
function T:PanelsOf(name)
    return self.panelsOf[name] or {}
end

--- Whether a panel is in use: a shared one always (the world view); one without a switch (7.x's and 5.x's screens, Game
--- Options) while its own interface is active, so in another it is off and cannot be turned on alone; another while its
--- switch is on in the profile.
function T:PanelInUse(panel)
    if panel.shared == true then return true end
    if not panel.switch then return panel.interface == self.active end
    return TK.Panels:IsOn(nil, panel)
end

--- Whether a component is in use: one of its panels is, or it has none (the global ones and the tools).
function T:InUse(name)
    local found = false
    for _, panel in ipairs(self:PanelsOf(name)) do
        if self:PanelInUse(panel) then return true end
        found = true
    end
    return not found
end

-- ----- the profile per interface -----

--- The profile to load at the start: the one last used with the active interface; for the default interface (Modern)
--- without one, the current profile as before interfaces (unless it is another interface's); for another interface without
--- one, its first profile (by its name), made from its defaults (T:Loaded).
function T:ProfileName()
    local id, m = self.active, TK.Machine:Get()
    local name = m.interfaceProfiles[id]
    if name and H:ProfileExists(name) then return name end
    if id == self:Default() then
        local current = H:ProfileGetCurrent()
        for interface, n in pairs(m.interfaceProfiles) do
            if n == current and interface ~= id then return "Default" end
        end
        return current
    end
    -- Astra's r8 review, 4: a profile of that name that is another interface's (or Modern's, from before interfaces) is not
    -- taken over: the first free name after it ("Test Interface 2") is the interface's.
    local base = self:Active().profileName or self:Active().name or id
    name = base
    for n = 2, 99 do
        if not H:ProfileExists(name) or m.profileInterfaces[name] == id then break end
        name = base .. " " .. n
    end
    return name
end

--- After the profile is loaded at the start: it is recorded as the one this interface uses (and again on every switch).
function T:Loaded()
    self:Remember()
    -- the owner's hotfix (core/bindings.lua): the global keys, then each key in the map its command belongs in
    TK.Bindings:ApplyGlobals()
    TK.Bindings:Park()
end

--- The keys a switch by key carried (T:SwitchTo), bound in the profile the switch ends in, each where its key is free and
--- its command has no key. That profile is final only in the world: at once after a switch made there (T:SwitchNow
--- loads the character's own for the interface), else once the character enters and its own is chosen
--- (TK.Characters:Enter: Astra's hotfix review, P2 4); keys act only in the world, so a carry made at the login screen
--- waits for it. Nothing is sent: these are the UI's bindings.
function T:BindCarried()
    local m = TK.Machine:Get()
    local carry = m.interfaceKeysCarried
    if not carry then return end
    m.interfaceKeysCarried = nil
    TK.Machine:MarkDirty()
    local map = TK.Bindings:Map()
    for _, c in ipairs(carry) do
        if map[c.key] == nil and #TK.Bindings:Keys(c.command) == 0 then SetBinding(c.key, c.command) end
    end
end

TK.On("PLAYER_ENTERING_WORLD", function() if T.active then T:BindCarried() end end)

--- s6-ui-core (round 61; the owner, 2026-10-06, through the head: the world's hover tooltips "enabled in the 7x interface"
--- are on in Modern and off in 7.x and 5.x): a migrate entry's set, { component = { key = value } }: settings given the
--- interface's own value, in its first profiles (T:ApplyDefaults) and once in those made before (T:Migrate), as the menu
--- button's switch is; the player's choice is kept after that, and a page's reset puts back the interface's value (as a
--- first profile has it: core/settings.lua's firstValues). Drawing only: nothing is sent.
local function setValues(m)
    for name, values in pairs(m.set or {}) do
        local c = TK.GetComponent(name)
        if c then
            local db = c:DB()
            for k, v in pairs(values) do db[k] = v end
        end
    end
end

--- A new profile's defaults as the active interface makes them (core/db.lua: a first profile, Create and Reset; Astra's r8
--- review, 2): Modern's are the default profile as it is; another interface's are its own panels on, every other interface's
--- off but those its manifest's enable lists (by panel id: s6-interface-5x round 12, interface-separation.md 5.13), the
--- bindings of the shared commands with the keys of the panels that are off given back and its own panels' keys where
--- free (Astra's r8 review, 1), its looks, and the profile marked with the interface.
--- s6-ui-core (round 61): and its migrate entries' set values (setValues, above).
function T:ApplyDefaults()
    if not self.active or self.active == self:Default() then return end
    local p, interface = TK.DB.profile, self:Active()
    p.interface = interface.id
    p.looks = { dialogs = interface.looks and interface.looks.dialogs or interface.id, cursors = interface.looks and interface.looks.cursors or "original" }
    local enable = {}
    for _, id in ipairs(interface.enable or {}) do enable[id] = true end
    local own = {}
    for _, other in ipairs(self.list) do
        for _, panel in ipairs(other.panels) do
            local on = ((other.id == interface.id or panel.shared == true) and panel.on ~= false)
                or (other.id ~= interface.id and enable[panel.id] == true)
            self:SetSwitch(panel, on)
            if on then own[#own + 1] = panel else self:DropKeys(panel) end
        end
    end
    if interface.defaults then interface.defaults(p) end
    for _, panel in ipairs(own) do self:AddKeys(panel) end
    for _, m in ipairs(interface.migrate or {}) do -- a first profile needs no carry-over, only the set values
        setValues(m) -- s6-ui-core (round 61)
        p.migrated[m.flag] = true
    end
    TK.DB:MarkDirty()
end

--- s6-interface-5x (round 12, build 46; interface-separation.md 5.13): the active interface's one-off carry-overs (its
--- manifest's migrate: { flag, off = { panel id } }), each applied once to each of its profiles made before it and
--- recorded under its flag (profile.migrated), so a panel the player turns on again stays on; a first profile has them
--- all (T:ApplyDefaults). off: those panels of the other interfaces turned off, with the keys they brought (7.x's and
--- 5.x's: Modern's windows and action wheel, which had no switch before round 12, so no player chose them; decision
--- 2026-10-05-first-profiles-only-their-own-panels). The profile is saved after (core/db.lua's Load). Nothing is sent.
--- s6-ui-core (round 60): on: those turned on (the menu button, a shared panel with a switch since this round, on in
--- 7.x's and 5.x's first profiles), with the keys they bring. s6-ui-core (round 61): set: settings given their values
--- (setValues, above).
function T:Migrate()
    local p, interface = TK.DB.profile, self:Active()
    if not self.active or p.interface ~= interface.id then return end -- (Modern's profiles name none, and it has none)
    for _, m in ipairs(interface.migrate or {}) do
        -- a carry-over a component recorded before under its own values (m.oldFlag = { component, key }) is done
        local old = m.oldFlag and p.components[m.oldFlag[1]]
        if not (p.migrated[m.flag] or (old and old[m.oldFlag[2]] == true)) then
            p.migrated[m.flag] = true
            local off, on = {}, {}
            for _, id in ipairs(m.off or {}) do off[id] = true end
            for _, id in ipairs(m.on or {}) do on[id] = true end -- s6-ui-core (round 60)
            for _, other in ipairs(self.list) do
                for _, panel in ipairs(other.panels) do
                    if other.id ~= interface.id and off[panel.id] then
                        self:SetSwitch(panel, false)
                        self:DropKeys(panel)
                    elseif other.id ~= interface.id and on[panel.id] then
                        self:SetSwitch(panel, true)
                        self:AddKeys(panel)
                    end
                end
            end
            setValues(m) -- s6-ui-core (round 61)
            TK.DB.migrated = true
        end
    end
end

-- ----- a profile holds only the panels in use (Mixing) -----

--- The components of the other interfaces' panels whose every panel is off in this profile: { name = { panels } }. Every
--- panel of a component counts (Astra's review of round 9): a shared one (the world view, every interface's) is always in
--- use, so its component is never left out; nor is one with a panel without a switch (7.x's screen, its map view kept in
--- Modern), although since round 13 it is loaded only in its own interface (T:PanelInUse).
function T:Unused()
    local own = TK.DB.profile.interface or self:Default()
    local state = {}
    for _, interface in ipairs(self.list) do
        if interface.id ~= own then
            for _, panel in ipairs(interface.panels) do
                if panel.component and TK.GetComponent(panel.component) then
                    local s = state[panel.component] or { off = true, panels = {} }
                    -- a switchless panel (Game Options, 7.x's screen) keeps its component's settings in every interface
                    local inUse = not panel.switch or self:PanelInUse(panel)
                    s.off = s.off and not inUse
                    s.panels[#s.panels + 1] = panel
                    state[panel.component] = s
                end
            end
        end
    end
    local out = {}
    for name, s in pairs(state) do
        if s.off then out[name] = s.panels end
    end
    return out
end

--- s6-interface-5x (round 12, build 46; the owner, 2026-10-05: "stuff from other interfaces shouldn't be enabled while you
--- are in a different interface anymore, unless you specifically have turned them on in addition"): whether a component
--- is an interface's panel (its folder under interfaces/) with no panel in use in this profile (T:InUse; round 13: a
--- switchless one only in its own interface), for the active interface's panels too. Its commands are then inert
--- (TK.Bindings:Inert) and its frames get no mover in edit mode (core/editmode.lua); since round 13 its code is not loaded
--- either.
function T:Dormant(name)
    -- Wire: a dormant component's commands are inert (TK.Bindings:Inert), so their keys send nothing, as a key 4a's
    -- UserPane::HandleKeyOrTextEvent 0x005A5BD0 has no case for; answering otherwise makes a panel that is off send.
    local c = TK.GetComponent(name)
    if not (c and c.dir and c.dir:sub(1, 11) == "interfaces/") then return false end
    return not self:InUse(name)
end

--- s6-optimize (round 28): the panels a page's switch turns on and off (T:Load's index), in the list's order, or nil.
function T:SwitchPanels(node, key)
    local switches = node and self.switches[node.id]
    return switches and switches[key]
end

--- What is saved of the profile (core/db.lua's store): without the settings and places of the other interfaces' panels that
--- are off, which it lists as unused; they come back off and at their defaults when it is loaded.
function T:Trimmed(data)
    if not self.active or data ~= TK.DB.profile then return data end
    data = TK.Bindings:Unoverlaid(data) -- the owner's hotfix: other interfaces' global keys are never saved here
    local unused = self:Unused()
    if not next(unused) then return data end
    local copy, places, names = {}, {}, {}
    for k, v in pairs(data) do copy[k] = v end
    copy.components, copy.positions = {}, {}
    for name, panels in pairs(unused) do
        names[#names + 1] = name
        for _, panel in ipairs(panels) do
            if panel.place then places[panel.place] = true end
        end
    end
    table.sort(names)
    for k, v in pairs(data.components) do
        if not unused[k] then copy.components[k] = v end
    end
    for k, v in pairs(data.positions) do
        if not places[k] then copy.positions[k] = v end
    end
    copy.unused = names
    return copy
end

--- After a profile is read (core/db.lua's Load and CopyFrom): the other interfaces' panels it left out (T:Trimmed) are
--- off, at their defaults.
function T:Untrim()
    local p = TK.DB.profile
    for _, name in ipairs(p.unused or {}) do
        for _, panel in ipairs(self:PanelsOf(name)) do self:SetSwitch(panel, false) end
    end
    p.unused = nil
end

--- Records the loaded profile as the active interface's, and the profile's interface (the Profiles page's switch and new
--- profile come here too).
function T:Remember()
    local m = TK.Machine:Get()
    if m.interfaceProfiles[self.active] ~= TK.DB.name or m.profileInterfaces[TK.DB.name] ~= self.active then
        m.interfaceProfiles[self.active] = TK.DB.name
        m.profileInterfaces[TK.DB.name] = self.active
        TK.Machine:MarkDirty()
    end
end

-- ----- resetting an interface (s6-interface-5x, round 11; interface-separation.md, 5.17; the decision
-- docs/user-related/decisions/2026-10-05-resetting-an-interface.md) -----

--- The profile an interface would load: in the world the character's for it, else the one last used with it; nil when
--- it has none yet (its first use makes one from its defaults). Only a profile recorded as that interface's (a name may
--- have been deleted and made again by another interface: Astra's review of round 11), as the character's entry checks.
function T:ProfileOf(id)
    local m = TK.Machine:Get()
    for _, name in ipairs({ TK.Characters:ProfileFor(id) or false, m.interfaceProfiles[id] or false }) do
        if name and H:ProfileExists(name) and (m.profileInterfaces[name] or self:Default()) == id then return name end
    end
end

--- Puts an interface back as a first start in it makes it (every panel on or off, their places, keys and looks): the
--- interface in use at once (its profile made again, as the Profiles page's Reset Profile does); another's profile is
--- marked, and loads as new the next time that interface is used (core/db.lua's Load). The other profiles, the
--- computer's settings and the characters' stores are left. It sends nothing: a profile changes, as on the Profiles page.
function T:Reset(id)
    if not self.byId[id] then return end
    if id == self.active then
        TK.DB:Reset()
        return
    end
    local name = self:ProfileOf(id)
    if not name then return end
    TK.Machine:Get().resetProfiles[name] = true
    TK.Machine:MarkDirty()
end

--- The Interface tab's Reset for the interface it shows (its General page, round 12): asks first, in the owner's words.
function T:AskReset(id)
    local interface = self.byId[id]
    if not interface then return end
    TK.UI.Confirm("Reset all settings for " .. (interface.name or id) .. "?", function() self:Reset(id) end)
end

--- Whether a profile is one of the active interface's (the Profiles page lists only those; a profile no interface recorded
--- is Modern's, as every profile from before interfaces).
function T:IsActiveProfile(name)
    return (TK.Machine:Get().profileInterfaces[name] or self:Default()) == self.active
end

-- A profile switched to, made or reset on the Profiles page is recorded as the active interface's.
TK.On("TK_PROFILE_CHANGED", function() if T.active then T:Remember() end end)

--- Sets a panel's switch in this profile (the first profile's defaults), in the settings its page shows.
function T:SetSwitch(panel, on)
    if not panel.switch then return end
    for _, node in ipairs(TK.Components:AllNodes()) do
        if node.id == panel.node and node.db then node.db()[panel.switch] = on end
    end
end

-- ----- mixing: the keys a panel brings -----

--- The keys a panel brings, { { command, key } }: its interface's list (panel.keys); for a panel of another interface than the
--- profile's whose buttons are bound by default (Modern's bars: panel.clicks, their frames' name but for the number),
--- the default bindings to them (Astra's r8 review, 1). In its own interface's profile such a panel's keys are the profile's
--- own bindings, as before interfaces.
function T:KeysOf(panel)
    if panel.keys then return panel.keys end
    if not panel.clicks or panel.interface == (TK.DB.profile.interface or self:Default()) then return {} end
    local out, pattern = {}, "^CLICK " .. panel.clicks .. "%d+$"
    -- s6-modular-g (round 19, the separation's step 8; 5.9): with the default bindings to its carrier slots (panel.hotkeys:
    -- the original's hotkeys its buttons show, bound to TK.Game.Hotkeys' carriers), the same keys as before the step
    local carried = {}
    for _, slot in ipairs(panel.hotkeys or {}) do carried[TK.Game.Hotkeys.Command(slot)] = true end
    for key, command in pairs(TK.DB.defaultBindings) do
        if command:match(pattern) or carried[command] then out[#out + 1] = { command = command, key = key } end
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end

--- A new profile's default keys of a panel that is off in it, given back (T:ApplyDefaults), where they still run its
--- commands.
function T:DropKeys(panel)
    local p, map = TK.DB.profile, TK.Bindings:Map()
    for _, k in ipairs(self:KeysOf(panel)) do
        if map[k.key] == k.command then
            map[k.key] = nil
            p.secondaryKeys[k.key] = nil
        end
    end
end

--- Turning a panel on adds each of its keys (panel.keys: { command, key }) that is free in this profile and records it.
--- A key already bound: the player was asked first (T:Blocks, the owner's hotfix of 2026-10-06, which answers open
--- question 1); once they chose to keep it there, it is left to its command and the panel's command stays without it.
function T:AddKeys(panel)
    local keys = self:KeysOf(panel)
    if #keys == 0 then return end
    local p, map = TK.DB.profile, TK.Bindings:Map()
    local added = p.panelKeys[panel.interface .. "." .. panel.id] or {}
    for _, k in ipairs(keys) do
        -- Astra's r8 review, 3: any command a binding may name ("CLICK <frame>" too), as the profile's check accepts
        if map[k.key] == nil and TK.Validate.BindingCommand(k.command, TK.DB.knownCommands) then
            map[k.key] = k.command
            added[#added + 1] = k.key
        end
    end
    p.panelKeys[panel.interface .. "." .. panel.id] = #added > 0 and added or nil
end

--- Turning it off removes exactly the keys it added, where they still run its commands; its commands' other keys are
--- parked with it (TK.Bindings:Park, the owner's hotfix), so they block no key in use.
function T:RemoveKeys(panel)
    local p, map = TK.DB.profile, TK.Bindings:Map()
    local id = panel.interface .. "." .. panel.id
    local commands = {}
    for _, k in ipairs(self:KeysOf(panel)) do commands[k.command] = true end
    for _, key in ipairs(p.panelKeys[id] or {}) do
        if commands[map[key]] then
            map[key] = nil
            p.secondaryKeys[key] = nil
        end
    end
    p.panelKeys[id] = nil
end

--- The owner's hotfix (2026-10-06): the keys a panel turned on would bring that are in use: its commands' parked keys
--- (core/bindings.lua) and the keys its interface gives it (T:KeysOf), each { key, command, holder }.
function T:Clashes(panel)
    local B, live, out, seen = TK.Bindings, TK.Bindings:Map(), {}, {}
    local function add(key, command)
        local holder = live[key]
        if holder and holder ~= command and not seen[key] then
            seen[key] = true
            out[#out + 1] = { key = key, command = command, holder = holder }
        end
    end
    for key, command in pairs(B:Parked()[panel.component] or {}) do add(key, command) end
    for _, k in ipairs(self:KeysOf(panel)) do add(k.key, k.command) end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end

--- The owner's hotfix (2026-10-06: "if you enable a interface panel for another interface ... that shares a hotkey it
--- should prevent you from enabling that interface and popup saying there is a conflict ... Cancel, Unbind X Y Z <its>
--- keybinds, Unbind X Y Z <these> keybinds ... clicking unbind will unbind it for that interface and then enable the
--- panel"): whether a panel's switch turned on waits for the player (core/settings.lua asks before it changes anything).
--- With clashes it asks: Cancel leaves the panel off; unbinding the panel's keys turns it on without them; unbinding
--- this interface's turns it on with them. Nothing is sent.
function T:Blocks(node, key, value)
    if not value or self.forcing or not node then return false end
    local panels = self:SwitchPanels(node, key)
    if not panels then return false end
    local panel = panels[1] -- the first panel of the switch, as the list orders them
    local clashes = self:Clashes(panel)
    if #clashes == 0 then return false end
    self:AskClashes(node, panel, clashes)
    return true
end

--- Retires a profile's question when that profile/interface is replaced. ReapplyAll also fires for an unchanged
--- profile, so compare its actual table, not its name (Reset and CopyFrom keep the name but replace the table).
--- WIRE: this extra UI question sends nothing; native modal/captured ownership remains EventDispatcher 0x004A7130.
--- The existing switch barrier still waits for held releases and their original waits. Letting an old answer change
--- the new profile's keys would change what its next UserPane 0x005A5BD0 input sends to the server.
function T:CloseStaleClash()
    local q = self.clashQuestion
    if not q or (q.profile == TK.DB.profile and q.interface == self.active) then return end
    self.clashQuestion = nil
    local window = TK.UI.choose
    if window and window.choices == q.choices then window:Hide() end
end

TK.On("TK_PROFILE_CHANGED", function() T:CloseStaleClash() end)
TK.On("TK_INTERFACE_CHANGED", function() T:CloseStaleClash() end)

--- The dialog itself. A key here that is another interface's global key cannot be unbound here (TK.Bindings:GlobalRefusal,
--- as every slot change: Astra's hotfix review, P2 2): its line says whose global it is, and the unbind of this
--- interface's keys leaves it out (left with none to unbind, that choice is not offered). Such a key of the panel's
--- command stays parked while the global holds it (TK.Bindings:Park).
function T:AskClashes(node, panel, clashes)
    local B = TK.Bindings
    local question = { profile = TK.DB.profile, interface = self.active }
    -- An answer already retained by the old window must be retired too, even if another question now uses its
    -- shared frame. Cancel/one accepted answer consumes this question without changing normal unbind behavior.
    -- WIRE: only the asked-about profile may change its bindings; otherwise its next UserPane 0x005A5BD0 command
    -- differs on the server. No packet, timer or captured-release ordering (EventDispatcher 0x004A7130) changes here.
    local function settle()
        if self.clashQuestion ~= question or question.profile ~= TK.DB.profile or question.interface ~= self.active then
            return false
        end
        self.clashQuestion = nil
        return true
    end
    local theirs = (self.byId[panel.interface] or {}).name or panel.interface
    local ours = self:Active().name or self.active
    local lines, keys, free, freeKeys = {}, {}, {}, {}
    for _, c in ipairs(clashes) do
        keys[#keys + 1] = B.KeyText(c.key)
        local global = B:GlobalRefusal(c.holder) and B:Globals()[c.holder]
        if not global then
            free[#free + 1] = c
            freeKeys[#freeKeys + 1] = B.KeyText(c.key)
        end
        local whose = global and ("global, " .. ((self.byId[global.from] or {}).name or global.from)) or ours
        lines[#lines + 1] = B.KeyText(c.key) .. ": " .. B:CommandText(c.command) .. " (" .. theirs .. ") / "
            .. B:CommandText(c.holder) .. " (" .. whose .. ")"
    end
    local function turnOn()
        self.forcing = true
        TK.Settings:SetOption(node.id, panel.switch, true)
        self.forcing = nil
    end
    local choices = {
        { "Cancel", settle },
        { "Unbind " .. table.concat(keys, ", ") .. " (" .. theirs .. " keybinds)", function()
            if not settle() then return end
            local parked = B:Parked()[panel.component] or {}
            for _, c in ipairs(clashes) do
                if parked[c.key] == c.command then parked[c.key] = nil end
            end
            turnOn() -- its keys in use stay with their commands (T:AddKeys adds only free ones)
        end },
    }
    if #free > 0 then
        choices[3] = { "Unbind " .. table.concat(freeKeys, ", ") .. " (" .. ours .. " keybinds)", function()
            if not settle() then return end
            local live, second = B:Map(), B:Secondary()
            for _, c in ipairs(free) do
                live[c.key] = nil
                second[c.key] = nil
                B:FollowGlobal(c.holder) -- (a global of this interface loses it everywhere)
            end
            turnOn()
        end }
    end
    question.choices = choices
    self.clashQuestion = question
    TK.UI.Choose((panel.name or panel.id) .. " shares keys with " .. ours .. ":\n" .. table.concat(lines, "\n"), choices)
end

--- The owner's hotfix (2026-10-06): for a command whose keys go to every interface (made global, or a global's new key:
--- core/bindings.lua B:GlobalUses), the other interfaces' profiles where one of its keys runs another command:
--- { key, holder, name (the interface's), profile }. Every profile of each other installed interface (Astra's hotfix
--- review, P2 1: each one's last used alone missed a character's own), by the interface it is recorded as (one recorded
--- as none is the default interface's, Modern's, as T:IsActiveProfile counts it; the guard keeps the literal out),
--- read as saved (never with an override: B:Unoverlaid). Read only.
function T:GlobalClashes(command, keys)
    local out, m = {}, TK.Machine:Get()
    -- s6-modular-g (round 19, step 8; Astra's pass 19-1): a profile not loaded since step 8 still names a hotkey by
    -- Modern's button; read as its load will carry it over (core/db.lua's DB:CarryRenamed), so it is no clash
    local renamed = TK.DB:Renamed()
    local names = TK.DB:List()
    table.sort(names)
    for _, name in ipairs(names) do
        local interface = self.byId[m.profileInterfaces[name] or self:Default()]
        if interface and interface.id ~= self.active then
            local p = H:ProfileLoad(name)
            local bindings = type(p) == "table" and type(p.bindings) == "table" and p.bindings or {}
            for _, key in ipairs(keys) do
                local holder = bindings[key]
                holder = renamed[holder] or holder -- s6-modular-g (round 19, step 8)
                if type(holder) == "string" and holder ~= command then
                    out[#out + 1] = { key = key, holder = holder, name = interface.name or interface.id, profile = name }
                end
            end
        end
    end
    return out
end

--- A setting changed on a page (core/settings.lua): a panel's switch adds or removes the keys its panel brings, parks
--- or unparks its commands' keys (the owner's hotfix), and loads or unloads the panel (s6-interface-5x round 13, step
--- 11: TK.Components:Sync).
function T:SettingChanged(node, key, value)
    for _, panel in ipairs(self:SwitchPanels(node, key) or {}) do
        if panel.keys or panel.clicks then
            if value then self:AddKeys(panel) else self:RemoveKeys(panel) end
            TK.DB:MarkDirty()
        end
        TK.Components:Sync()
        TK.Bindings:Park() -- the owner's hotfix: its commands' keys to the map they belong in now
        -- s6-interface-5x (round 12, build 46; Astra's wrap-up review): every switch pushes the key layer again,
        -- as a panel turned on or off makes its component's commands act or go inert (TK.Bindings:Inert), with
        -- keys of its own or not (Modern's nameplates and N). Wire: without this push a panel turned off would
        -- still send by its keys, where 4a's UserPane::HandleKeyOrTextEvent 0x005A5BD0 sends nothing
        TK.FireEvent("UPDATE_BINDINGS")
    end
end

-- ----- the profile's fields -----

--- The panels' added keys as saved: { ["<interface>.<panel>"] = { key, ... } }, the keys kept only while bound.
function T.NormalizePanelKeys(v, bindings)
    local out = {}
    if type(v) ~= "table" then return out end
    for id, keys in pairs(v) do
        if type(id) == "string" and type(keys) == "table" then
            local kept = {}
            for _, key in ipairs(keys) do
                if type(key) == "string" and bindings[key] then kept[#kept + 1] = key end
            end
            if #kept > 0 then out[id] = kept end
        end
    end
    return out
end

--- The owner's hotfix (2026-10-06; core/bindings.lua): the inert commands' keys as saved, component -> { key -> command },
--- each kept while it names a command a binding may name.
function T.NormalizeParked(v, knownCommands)
    local out = {}
    for id, map in pairs(type(v) == "table" and v or {}) do
        if type(id) == "string" and type(map) == "table" then
            local kept = {}
            for key, command in pairs(map) do
                if type(key) == "string" and #key > 0 and TK.Validate.BindingCommand(command, knownCommands) then kept[key] = command end
            end
            if next(kept) then out[id] = kept end
        end
    end
    return out
end

--- The carry-overs applied to the profile (T:Migrate): { flag = true }.
function T.NormalizeMigrated(v)
    local out = {}
    for flag, done in pairs(type(v) == "table" and v or {}) do
        if type(flag) == "string" and done == true then out[flag] = true end
    end
    return out
end

--- The components the saved profile left out (T:Trimmed), as names.
function T.NormalizeUnused(v)
    local out = {}
    for _, name in ipairs(type(v) == "table" and v or {}) do
        if type(name) == "string" then out[#out + 1] = name end
    end
    return out
end

--- The looks chosen in the profile: the dialogs' (an interface with a dialogs look; the default interface's at first) and
--- the cursors'.
function T.NormalizeLooks(v)
    v = type(v) == "table" and v or {}
    return { dialogs = type(v.dialogs) == "string" and v.dialogs or T:Default(),
             cursors = type(v.cursors) == "string" and v.cursors or "original" }
end

-- ----- the looks -----

--- The interfaces that have a dialogs look (interfaces/<id>/dialogs/), for the Interfaces page: { { value, text } }.
function T:DialogLooks()
    local out = {}
    for _, interface in ipairs(self.list) do
        if interface.looks and interface.looks.dialogs == interface.id then out[#out + 1] = { value = interface.id, text = interface.name } end
    end
    return out
end

--- s6-interface-5x-b: the cursor sets for the Interfaces page: the original's and each installed interface's own (its
--- looks' cursors, as 5.x's "533"): { { value, text } }.
function T:CursorLooks()
    local out = { { value = "original", text = "The original's" } }
    for _, interface in ipairs(self.list) do
        local set = interface.looks and interface.looks.cursors
        if set and set ~= "original" then out[#out + 1] = { value = set, text = interface.name .. "'s" } end
    end
    return out
end

--- The dialogs' look of the profile, loaded (the default interface's, Modern's, when the chosen one is not installed).
function T:DialogsLook()
    local id = TK.DB.profile and TK.DB.profile.looks and TK.DB.profile.looks.dialogs or self:Default()
    local interface = self.byId[id]
    if not (interface and interface.looks and interface.looks.dialogs == id) then id = self:Default() end
    return require("interfaces." .. id .. ".dialogs")
end
