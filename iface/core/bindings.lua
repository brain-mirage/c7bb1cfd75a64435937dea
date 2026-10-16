-- Key bindings: binding -> command, saved per profile (plan D24: almost every key rebindable, as in WoW). A binding is
-- a key or a mouse button with any modifiers, or a chord of two keys (s6-input's BindingNames):
--
--   "W", "CTRL-SHIFT-X", "F5"          a key under modifiers (ALT-CTRL-SHIFT- order)
--   "BUTTON1".."BUTTON5"                 the left, right, middle and side buttons ("SHIFT-BUTTON2")
--   "MOUSEWHEELUP", "MOUSEWHEELDOWN"     the wheel over the map ("CTRL-MOUSEWHEELUP")
--   "X+C"                                C pressed while X is held (no modifier); X keeps its own binding
--
-- Commands:
--
--   CLICK <frame name>   press the button: the pushed look while the key is held, a click on key down
--   a named command      registered with B:RegisterCommand (TOGGLECHARACTER, TOGGLESPELLBOOK, TOGGLEBAG, ...)
--   a builtin command    the logic's own (walking, the view shift, the target keys, the map's buttons; B.builtins):
--                        the key posts the original key's record, so the rules see what the original's key did
--   MACRO <reference>    s6-macros: run one of the player's macros ("MACRO account:3"); the key freezes its text
--
-- Classic commands (plan D19) are a preset of this table (B:ApplyPreset, B:RestorePreset), not a layer of their own.
--
-- A command has one or two bindings on the Key Bindings page. The input path (s6-input) looks the table up at each
-- press; offline the keys reach this file instead.
--
-- s6-ui-bars (plan D24, as WoW's Key Bindings frame): the two are a primary and an optional secondary key (the
-- secondary ones are marked in the profile's secondaryKeys; a bar button shows its primary). A key names one command:
-- binding it elsewhere takes it from the command that had it, and the page says "<command> Function is Now Unbound!"
-- in red when that command is left with no key, else "Key Bound Successfully" (B:SetSlot, B:BindingResult); checked
-- against WoW 3.3.5a's own wording and frame (W:\wow-client-unpacked, read as a reference only).
--
-- Bindings act only in the world; on the login screen only Escape and key capture reach Lua.
--
-- Key-binding mode (Edit Mode's Keybinds since s6-ui-core round 54, like KeyBound): hover a bindable button and
-- press a key to make it the button's primary key; Escape clears the hovered button's bindings; Escape with nothing
-- hovered, Keybinds again, or Edit Mode's Unlock or close, leaves the mode.

local U = TK.Util
local W = TK.UI

local B = { held = {}, bindable = {} }
TK.Bindings = B

function B:Map() return TK.DB.profile.bindings end

-- ----- each interface's keys apart; global keys (the owner's hotfix, 2026-10-06) -----
--
-- The owner: "setting a hotkey for a interfaces seems to block you from setting it in another interface even though its
-- not enable which doesnt make sense". A command of an interface's panel that is off (inert: B:Inert) keeps its keys in
-- its component's own map in the profile (parkedBindings[<component>]: key -> command; one per component, so two
-- panels' keys never collide there: Astra's after-review, P1 2), not in the live map the keys run from, so it blocks no
-- key in use. The page shows and changes them there (B:MapFor). When its panel is turned on
-- they go back to the live map (B:Park); a key in use there is a clash, which the player settles first
-- (TK.Interfaces:Blocks). Nothing is sent by any of it: these are the UI's bindings.
--
-- Global keys (the owner: "make global ... should make that hotkey stick between interface changes"; "it would
-- automatically override all profiles irregardless of what they set"): a command marked global belongs to the interface
-- it was marked in (TK.Machine's globalBindings: command -> { from = <interface>, keys = { key, key } }). There its keys
-- are its profile's own and change as any key does. In every other interface they are an override laid over the profile
-- while it is loaded (B:ApplyGlobals, B.overlay), never saved in it (B:Unoverlaid): its own binding comes back once the
-- global goes. There they cannot be changed: unbinding it, or binding its key to another command, is refused
-- (B:GlobalRefusal). A key another interface uses (in any of its profiles) cannot be made global (B:SetGlobal), nor
-- given to a global command later in its own interface (B:GlobalRefusal, B:GlobalUses).

--- The parked maps: component -> { key -> command }.
function B:Parked()
    local p = TK.DB.profile
    if type(p.parkedBindings) ~= "table" then p.parkedBindings = {} end
    return p.parkedBindings
end

--- The map a command's keys are in: its component's parked map while it is inert, else the live map.
function B:MapFor(command)
    local c = self.commands[command]
    if not (c and self:Inert(c)) then return self:Map() end
    local parked = self:Parked()
    parked[c.component] = parked[c.component] or {}
    return parked[c.component]
end

--- Moves each key to the map its command belongs in now: an inert command's out of the live map into its interface's
--- parked map, and a parked one whose command acts again back into the live map where the key is free there (a key in
--- use stays parked: TK.Interfaces:Blocks settles such a clash before the panel is turned on).
function B:Park()
    local live, parked, moved = self:Map(), self:Parked(), false
    -- the first hotfix kept them by interface: each key goes to its command's component
    local old = {}
    for id in pairs(parked) do
        if not TK.GetComponent(id) then old[#old + 1] = id end
    end
    for _, id in ipairs(old) do
        for key, command in pairs(parked[id]) do
            local c = self.commands[command]
            if c and c.component then
                parked[c.component] = parked[c.component] or {}
                parked[c.component][key] = parked[c.component][key] or command
            end
        end
        parked[id] = nil
        moved = true
    end
    for key, command in pairs(live) do
        local c = self.commands[command]
        if not self.overlay[key] and c and self:Inert(c) then -- (an override stays: never saved)
            parked[c.component] = parked[c.component] or {}
            parked[c.component][key] = command -- the player's latest binding of the key in this component
            live[key] = nil
            moved = true
        end
    end
    for _, map in pairs(parked) do
        for key, command in pairs(map) do
            local c = self.commands[command]
            if c and not self:Inert(c) and live[key] == nil then
                live[key], map[key] = command, nil
                moved = true
            end
        end
    end
    if moved then
        TK.DB:MarkDirty()
        TK.FireEvent("UPDATE_BINDINGS")
    end
end

--- The global commands: command -> { from = <interface>, keys = { key, key } } (the computer's).
function B:Globals()
    local m = TK.Machine:Get()
    if type(m.globalBindings) ~= "table" then m.globalBindings = {} end
    return m.globalBindings
end

function B:IsGlobal(command) return type(self:Globals()[command]) == "table" end

local function interfaceName(id)
    local interface = TK.Interfaces:Get(id)
    return interface and interface.name or tostring(id)
end

--- The overrides laid over the loaded profile: key -> { original = command or false, secondary = its mark }.
B.overlay = {}

--- Takes the overrides off the profile (each key's own binding back), for B:ApplyGlobals and a preset's snapshot.
function B:LiftGlobals()
    local map, second = self:Map(), self:Secondary()
    if self.overlayMap == map then
        for key, o in pairs(self.overlay) do
            map[key], second[key] = o.original or nil, o.secondary
        end
    end
    self.overlay, self.overlayMap = {}, nil
end

--- Lays the other interfaces' global keys over the profile just loaded (TK.Interfaces:Loaded), each key's own binding
--- kept aside for saving (B:Unoverlaid).
function B:ApplyGlobals()
    -- s6-optimize (round 28): the keys laid over this profile before (key -> command), so that the key layer is pushed
    -- again only when this changes one (it runs at every load, twice: TK.Interfaces:Loaded and TK_PROFILE_CHANGED).
    -- Wire: the key layer (B:PushKeys) decides which command each key runs, and so what it sends; a change here that
    -- leaves a changed key unpushed makes a key send what it no longer should (B:Inert: 4a's
    -- UserPane::HandleKeyOrTextEvent 0x005A5BD0 sends nothing for a key it has no case for).
    local map, before = self:Map(), {}
    if self.overlayMap == map then
        for key in pairs(self.overlay) do before[key] = map[key] end
    end
    self:LiftGlobals() -- laid over this profile already: taken off first
    local second, active = self:Secondary(), TK.Interfaces.active
    self.overlayMap = map
    for command, g in pairs(self:Globals()) do
        if type(g) == "table" and g.from ~= active and type(g.keys) == "table" then
            for _, key in ipairs(g.keys) do
                if type(key) == "string" and map[key] ~= command and not self.overlay[key] then
                    self.overlay[key] = { original = map[key] or false, secondary = second[key] }
                    map[key], second[key] = command, nil
                end
            end
        end
    end
    local changed = false
    for key in pairs(self.overlay) do
        if before[key] ~= map[key] then changed = true end
        before[key] = nil
    end
    if changed or next(before) ~= nil then TK.FireEvent("UPDATE_BINDINGS") end
end

--- The profile as it is saved: without the other interfaces' global keys, its own bindings where they lie.
function B:Unoverlaid(data)
    if not next(self.overlay) or data.bindings ~= self.overlayMap then return data end
    local copy = {}
    for k, v in pairs(data) do copy[k] = v end
    copy.bindings, copy.secondaryKeys = TK.Util.Copy(data.bindings), TK.Util.Copy(data.secondaryKeys or {})
    for key, o in pairs(self.overlay) do
        copy.bindings[key] = o.original or nil
        copy.secondaryKeys[key] = o.secondary
    end
    return copy
end

-- A profile switched to, made or reset on the Profiles page gets the overrides and its keys' maps too.
TK.On("TK_PROFILE_CHANGED", function()
    if TK.Interfaces.active then
        B:ApplyGlobals()
        B:Park()
    end
end)

--- Where keys are in use outside this interface, for a command whose keys go to every interface (the owner: "it checks if
--- other profiles already bind that key and tells you Keybind Already in Use in [x interface y interface....]"): every
--- profile of each other interface that binds one to another command (TK.Interfaces:GlobalClashes), and the other
--- interfaces' global keys. Returns the interfaces' names and a line per use; both are empty when the keys are free.
--- Read only. "Make global" and every later change of a global command's keys in its own interface run it (Astra's
--- hotfix review, P2 3).
function B:GlobalUses(command, keys)
    local lines, names, seen = {}, {}, {}
    local function inUse(name, line)
        if not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
        lines[#lines + 1] = line
    end
    for _, c in ipairs(TK.Interfaces:GlobalClashes(command, keys)) do
        inUse(c.name, B.KeyText(c.key) .. ": " .. self:CommandText(c.holder) .. " (" .. c.name .. ", " .. c.profile .. ")")
    end
    -- Every other global, this interface's own included (Astra's hotfix re-review, P2): two commands of one interface
    -- can hold the same key apart in their parked maps (an inert command's is its component's, not the live map), so a
    -- same-interface global could clash too; a key is one global.
    for other, og in pairs(self:Globals()) do
        if other ~= command and type(og) == "table" then
            for _, key in ipairs(og.keys or {}) do
                for _, k in ipairs(keys) do
                    if k == key then
                        inUse(interfaceName(og.from), B.KeyText(key) .. ": " .. self:CommandText(other) .. " (global, "
                            .. interfaceName(og.from) .. ")")
                    end
                end
            end
        end
    end
    return names, lines
end

--- Why changing a command's keys here is refused (a line to show), or nil. A global command's keys belong to the interface
--- it was made global in, and a key another interface made global is not free here (the owner's words). In its own
--- interface, a global command's new key must be free in the other interfaces too, as when it was made global (Astra's
--- hotfix review, P2 3). Every change of a slot runs it: the page's capture, Edit Mode's Keybinds, the page's Reset
--- (B:ResetKeys) and the clash dialog (TK.Interfaces:AskClashes).
function B:GlobalRefusal(command, binding)
    local active, globals = TK.Interfaces.active, self:Globals()
    local g = globals[command]
    if type(g) == "table" and g.from ~= active then
        return "Global keybinds must be unbound from the original " .. interfaceName(g.from) .. " interface."
    end
    if binding then
        for other, og in pairs(globals) do
            if other ~= command and type(og) == "table" and og.from ~= active then
                for _, key in ipairs(og.keys or {}) do
                    if key == binding then
                        return B.KeyText(binding) .. " is already bound globally from " .. interfaceName(og.from) .. ": "
                            .. self:CommandText(other) .. "."
                    end
                end
            end
        end
        if type(g) == "table" and self:MapFor(command)[binding] ~= command then
            local names, lines = self:GlobalUses(command, { binding })
            if #lines > 0 then return "Keybind Already in Use in " .. table.concat(names, ", ") .. ". " .. lines[1] end
        end
    end
end

--- In the interface a command was made global in, its keys follow it to every interface (B:ApplyGlobals): after any
--- change of its keys there (a slot, the page's Reset, Escape, the clash dialog), and of a key it lost.
function B:FollowGlobal(command)
    local g = command and self:Globals()[command]
    if type(g) == "table" and g.from == TK.Interfaces.active then
        g.keys = self:Keys(command)
        TK.Machine:MarkDirty()
    end
end

--- Marks a command global (on) or not, here. Marked, its keys here go to every interface; a key another interface's
--- profile uses for another command, or another interface's global key, is refused (the owner: "its not allowed").
--- Unmarking is refused outside the interface it was marked in. onDone runs after either.
function B:SetGlobal(command, on, onDone)
    local g = self:Globals()
    if not on then
        local refused = self:GlobalRefusal(command)
        if refused then
            TK.Popup(refused, "Global Key")
        else
            g[command] = nil
            TK.Machine:MarkDirty()
        end
        if onDone then onDone() end
        return
    end
    local keys = self:Keys(command)
    local names, lines = self:GlobalUses(command, keys)
    if #lines > 0 then
        TK.Popup("Keybind Already in Use in " .. table.concat(names, ", ") .. ".\n" .. table.concat(lines, "\n"),
            "Keybind Already in Use")
    else
        g[command] = { from = TK.Interfaces.active, keys = keys }
        TK.Machine:MarkDirty()
    end
    if onDone then onDone() end
end

--- The Key Bindings page's Reset: the commands shown (command -> true) back to their default keys, as one group; a
--- default key now bound to a command not reset with them is left to it. Like every slot change it keeps to
--- B:GlobalRefusal (Astra's hotfix review, P2 2): a command whose keys are another interface's is left as it is, and no
--- default key is taken that is another interface's global key or, for a command global here, in use in another
--- interface or by another global. Every command's keys are taken off first, and the globals here follow
--- (B:FollowGlobal), before any default is given back: the checks then see the group's keys as they are now, so two
--- globals of this interface that held each other's default keys each get their own back (Astra's r58-2 review, P2:
--- checked one at a time against the other's old global keys, both were left unbound).
function B:ResetKeys(shown)
    local second, group = self:Secondary(), {}
    for command in pairs(shown) do
        if not self:GlobalRefusal(command) then group[#group + 1] = command end
    end
    table.sort(group)
    for _, command in ipairs(group) do
        local map = self:MapFor(command) -- an inert command's own map (the owner's hotfix)
        for k, c in pairs(map) do
            if c == command then
                map[k] = nil
                second[k] = nil
            end
        end
        self:FollowGlobal(command)
    end
    -- (a key is one command's default, so no two of the group want the same key: a taken one is another command's)
    for _, command in ipairs(group) do
        local map = self:MapFor(command)
        for k, c in pairs(TK.DB.defaultBindings) do
            if c == command and map[k] == nil and not self:GlobalRefusal(command, k) then map[k] = command end
        end
        self:FollowGlobal(command)
    end
end

function SetBinding(key, command)
    local map = B:Map()
    map[key] = command
    TK.DB:MarkDirty()
    TK.FireEvent("UPDATE_BINDINGS")
end

--- The keys bound to a command, the primary first (as WoW's: B:Keys).
function GetBindingKey(command)
    return table.unpack(B:Keys(command))
end

function GetBindingAction(key)
    return B:Map()[key]
end

--- Registers a button as bindable in key-binding mode, with its command and a name for the tooltip.
function B:RegisterBindable(button, command, name)
    self.bindable[button] = { command = command, name = name }
end

--- Named commands, in the order they were registered: { name, text, fn }.
B.commands, B.commandList = {}, {}

--- Registers a named command a key can be bound to; fn runs on key down. action ({ kind, slot, amount, text }) is
--- the command's action, if it is one: it goes with the key, so the press freezes it before fn runs (plan 5.9).
--- up runs on the key's release, as that release's input: it may run a control's action then (TK.Actions:RunFrame, the
--- action wheel's pick). builtin: the logic carries it out itself (B.builtins); fn and action are then nothing.
--- s6-interface-5x (round 12, build 46): the component whose file or OnEnable registers it is recorded (component), so
--- that the command is inert while that interface's panel is off (B:Inert). Round 13 (step 11): a command already
--- declared or registered keeps its record and its place on the Key Bindings page; this fills it in.
function B:RegisterCommand(name, text, fn, action, up, builtin)
    local owner = TK.Components.loading or TK.Components.current
    local c = self.commands[name]
    if not c then
        c = { name = name }
        self.commandList[#self.commandList + 1] = c
        self.commands[name] = c
    end
    c.text, c.fn, c.action, c.up, c.builtin = text, fn, action, up, builtin or nil
    c.component = owner and owner.name or nil
    TK.DB.knownCommands[name] = true
end

--- s6-interface-5x (round 13, the separation's step 11; interface-separation.md 5.18): a command a component's manifest
--- declares (core/components.lua: Declare), known before the profile loads whether its code is loaded or not, so its
--- bindings are kept and listed; until its main.lua registers it (B:RegisterCommand) it has no function, and it is inert
--- (B:Inert: its component is not in use).
function B:Declare(name, text, component)
    if self.commands[name] then return end
    local c = { name = name, text = text, component = component }
    self.commandList[#self.commandList + 1] = c
    self.commands[name] = c
    TK.DB.knownCommands[name] = true
end

--- A component unloaded (TK.Components:Unload): its commands keep their records, bindings and place, without their
--- functions and actions. Wire: their keys are then inert (B:Inert), as an unbound key; changing this changes what the
--- server sees.
function B:Withdraw(component)
    for _, c in ipairs(self.commandList) do
        if c.component == component then c.fn, c.action, c.up = nil, nil, nil end
    end
end

-- what a frame of a panel turned off was bound as goes with it (TK.Components:Unload)
TK.OnWithdraw(function()
    for button in pairs(B.bindable) do
        if TK.IsDead(button) then B.bindable[button] = nil end
    end
end)

--- s6-interface-5x (round 12, build 46; the owner, 2026-10-05: another interface's things are off unless turned on): a
--- command of an interface's panel whose every panel is off (TK.Interfaces:Dormant: Modern's action wheel in a 7.x
--- profile; N is the game layer's since s6-play-modes' W6) does nothing, its binding kept (parked: B:Park). Wire: its key
--- then does what an unbound key does, nothing (no entry in the key layer, B:PushKeys, so no action is frozen and nothing
--- is sent), as a key no pane takes in 4a (UserPane::HandleKeyOrTextEvent 0x005A5BD0 sends nothing for a key it has no
--- case for); giving such a key its action would make a panel that is off send. Round 13 (step 11): such a command's
--- component is not loaded, and a declared command not registered yet has no function either.
function B:Inert(c)
    return c.component ~= nil and TK.Interfaces:Dormant(c.component)
end

--- s6-interface-5x (round 13, the separation's step 11; interface-separation.md 5.18): the name of the panel a command
--- waits for while it is inert (B:Inert), which the Key Bindings page shows greyed after it, "(off: <name>)"; nil when
--- it acts.
function B:OffPanel(c)
    if not self:Inert(c) then return nil end
    local panel = TK.Interfaces:PanelsOf(c.component)[1]
    return panel and panel.name or c.component
end

local function runCommand(command, down)
    local named = B.commands[command]
    if named and B:Inert(named) then return false end
    if named then
        -- s6-interface-5x (round 13): a declared command whose code is not loaded does nothing (B:Declare). Wire: as an
        -- unbound key; changing this changes what the server sees.
        if not named.fn and not named.up and not named.builtin then return false end
        if down then TK.SafeCall(named.fn) elseif named.up then TK.SafeCall(named.up) end
        return true
    end
    if command:sub(1, 6) == "MACRO " then
        -- s6-macros: the key froze the macro's text (the key layer below); the press runs it.
        if down then TK.Actions:RunFrozen() end
        return true
    end
    local target = command:match("^CLICK (.+)$")
    if target then
        local f = _G[target]
        if not f then return false end
        if down then
            -- Only a visible button is pressed, or a bar's (a bar that is off keeps its keys: s6-ui-bars); a release
            -- always lets go, even of a button hidden meanwhile (review R2.6).
            if not f:IsVisible() and not f.keyWhileHidden then return false end
            f:SetButtonState("PUSHED")
            f:Click("LeftButton")
        else
            f:SetButtonState("NORMAL")
        end
        return true
    end
    return false
end

-- ----- key-binding mode -----

-- s6-ui-core (round 54; the owner, 2026-10-05): key-binding mode is Edit Mode's Keybinds (core/editmode.lua), whose
-- dialog shows its line and what each key did (Mode:Status); it had a dialog of its own, opened from the Key Bindings page.
local Mode = { active = false }
TK.KeyBindMode = Mode

function Mode:Enable()
    self:CancelCapture()
    self.active = true
    self:Status("")
    TK.FireEvent("TK_KEYBIND_MODE", true)
end

function Mode:Disable()
    if not self.active then return end
    self.active = false
    TK.FireEvent("TK_KEYBIND_MODE", false)
end

--- What the last key did, in Edit Mode's dialog (green, or red for a key that could not be bound).
function Mode:Status(text, r, g, b)
    TK.EditMode:SetStatus(text, r, g, b)
end

local function hoveredBindable()
    local f = GetMouseFocus()
    while f do
        local b = B.bindable[f]
        if b then return f, b end
        f = f:GetParent()
    end
end

--- Binds the next key, mouse button, wheel turn or chord to a command's slot (1 or 2; the Key Bindings page). A key is
--- taken with its modifiers at its release, so a second key pressed while it is held makes a chord ("X+C"); Escape
--- clears the slot. The page's slot button hands its mouse buttons and wheel over (CaptureMouse, CaptureWheel).
--- onDone(binding, was) is told the binding and the command that had it before, if another.
function Mode:Capture(command, name, onDone, slot)
    self.capture = { command = command, name = name, onDone = onDone, slot = slot or 1 }
end

--- Forgets a pending capture: its page closed or changed, or the profile or game state changed (review R2.3).
function Mode:CancelCapture()
    self.capture = nil
end

TK.On("TK_PROFILE_CHANGED", function() Mode:CancelCapture() end)
TK.On("TK_GAME_STATE", function() Mode:CancelCapture() end)

--- Escape over a button in key-binding mode: the command loses every key.
local function unbindAll(command)
    local refused = B:GlobalRefusal(command) -- the owner's hotfix: another interface's global key
    if refused then return refused end
    local map, second = B:MapFor(command), B:Secondary()
    for k, c in pairs(map) do
        if c == command then
            map[k] = nil
            second[k] = nil
        end
    end
    B:FollowGlobal(command) -- (its own interface: GlobalRefusal let it through) its global keys go too
    TK.DB:MarkDirty()
    TK.FireEvent("UPDATE_BINDINGS")
end

local function finishCapture(binding)
    local c = Mode.capture
    Mode.capture = nil
    -- the owner's hotfix (2026-10-06): another interface's global key is refused, with its line
    local refused = B:GlobalRefusal(c.command, binding)
    if refused then
        if c.onDone then TK.SafeCall(c.onDone, binding, nil, nil, refused) end
        return true
    end
    local was, unbound = B:SetSlot(c.command, c.slot, binding)
    if c.onDone then TK.SafeCall(c.onDone, binding, was, unbound) end
    return true
end

--- A key during a capture: its press waits (a second key's press makes a chord), its release binds it; Escape first
--- clears the slot.
function Mode:OnCaptureKey(key, down)
    local c = self.capture
    local bare = U.BareKey(key)
    if down then
        if not c.pending then
            if bare == "ESCAPE" then return finishCapture(nil) end
            c.pending, c.pendingBare = key, bare
        elseif bare ~= c.pendingBare then
            -- s6-input (the owner's hotfix, 2026-10-06): live, the logic names a key pressed while another is held by its
            -- chord already ("A+D", InputHost.UiKey), which was bound as "A+A+D"
            return finishCapture(bare:find("+", 2, true) and bare or c.pendingBare .. "+" .. bare)
        end
        return true
    end
    if c.pending and bare == c.pendingBare then return finishCapture(c.pending) end
    return true
end

B.MOUSE = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function modifiers()
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
end

--- A mouse button pressed on the capturing slot's button: that button, with the modifiers held.
function Mode:CaptureMouse(button)
    if not self.capture or not B.MOUSE[button] then return false end
    return finishCapture(modifiers() .. B.MOUSE[button])
end

--- The wheel turned on the capturing slot's button.
function Mode:CaptureWheel(delta)
    if not self.capture then return false end
    return finishCapture(modifiers() .. (delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
end

local MOUSE_TEXT = { BUTTON1 = "Left Button", BUTTON2 = "Right Button", BUTTON3 = "Middle Button", BUTTON4 = "Button 4",
    BUTTON5 = "Button 5", MOUSEWHEELUP = "Wheel Up", MOUSEWHEELDOWN = "Wheel Down" }

function B.IsMouse(binding) return MOUSE_TEXT[U.BareKey(binding)] ~= nil end

--- A binding as the page shows it: "Ctrl-Shift-X", "Shift-Right Button", "X+C".
function B.KeyText(binding)
    if not binding or binding == "" then return "" end
    local bare = U.BareKey(binding)
    local prefix = binding:sub(1, #binding - #bare):gsub("ALT%-", "Alt-"):gsub("CTRL%-", "Ctrl-"):gsub("SHIFT%-", "Shift-")
    return prefix .. (MOUSE_TEXT[bare] or bare)
end

--- s6-ui-bars (plan D24, as WoW's Key Bindings): the keys in a command's second slot, the secondary ones (key -> true).
--- A command's other keys are its primary (the first slot), so a profile without the mark has every key first.
function B:Secondary()
    local p = TK.DB.profile
    p.secondaryKeys = p.secondaryKeys or {}
    return p.secondaryKeys
end

--- Whether binding a comes before b in a command's slots (second: B:Secondary()).
local function before(a, b, second)
    local sa, sb = second[a] == true, second[b] == true
    if sa ~= sb then return sb end
    local ma, mb = B.IsMouse(a), B.IsMouse(b)
    if ma ~= mb then return mb end
    if #a ~= #b then return #a < #b end
    return a < b
end

--- A command's bindings in their slots: the primary, then the secondary (s6-ui-bars); among keys of one slot (a preset's
--- or an older profile's), the keys, then the mouse's; the shorter first (W before UP), then alphabetical.
function B:Keys(command)
    local keys, second = {}, self:Secondary()
    for k, c in pairs(self:MapFor(command)) do
        if c == command then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return before(a, b, second) end)
    return keys
end

--- s6-optimize: every bound command's first key (GetBindingKey's first result), in one pass over the bindings, for a
--- refresh that asks for many commands (the bars' 120 buttons each scanned them all).
function B:PrimaryKeys()
    local first, second = {}, self:Secondary()
    local function scan(map)
        for k, c in pairs(map) do
            if first[c] == nil or before(k, first[c], second) then first[c] = k end
        end
    end
    scan(self:Map())
    for _, map in pairs(self:Parked()) do scan(map) end -- the owner's hotfix: inert commands' keys too
    return first
end

--- s6-optimize (round 9): every bound command's keys, each list in B:Keys's order, in one pass over the bindings, for a
--- page that shows many commands' keys (the Key Bindings page's rows each scanned them all).
function B:KeysByCommand()
    local all, second = {}, self:Secondary()
    local function scan(map)
        for k, c in pairs(map) do
            local keys = all[c]
            if not keys then
                keys = {}
                all[c] = keys
            end
            keys[#keys + 1] = k
        end
    end
    scan(self:Map())
    for _, map in pairs(self:Parked()) do scan(map) end -- the owner's hotfix: inert commands' keys too
    for _, keys in pairs(all) do table.sort(keys, function(a, b) return before(a, b, second) end) end
    return all
end

--- Puts a binding in a command's slot (1 or 2; nil clears it), as WoW's Key Bindings frame does (s6-ui-bars): the other
--- slot keeps its key (the same key in both slots is one key), and a second slot with the first empty moves up. A binding
--- names one command: the one that had it loses it. Returns that command, and whether it is now bound to nothing (WoW's
--- "Function is Now Unbound!").
function B:SetSlot(command, slot, binding)
    local map, second = self:MapFor(command), self:Secondary() -- an inert command's own map (the owner's hotfix)
    local keys = self:Keys(command)
    local slots = { keys[1], keys[2] }
    if slots[slot] then
        map[slots[slot]] = nil
        second[slots[slot]] = nil
    end
    local was
    if binding then
        was = map[binding]
        if was == command then was = nil end
        map[binding] = command
        if slots[3 - slot] == binding then slots[3 - slot] = nil end
    end
    slots[slot] = binding
    if not slots[1] then slots[1], slots[2] = slots[2], nil end
    if slots[1] then second[slots[1]] = nil end
    if slots[2] then second[slots[2]] = true end
    TK.DB:MarkDirty()
    -- the owner's hotfix: in the interface a command was made global in, its keys follow it to every interface
    -- (B:ApplyGlobals), and so does the loss of a key it had
    self:FollowGlobal(command)
    self:FollowGlobal(was)
    TK.FireEvent("UPDATE_BINDINGS")
    return was, was ~= nil and next(self:Keys(was)) == nil
end

--- WoW's Key Bindings lines (as its 3.3.5a interface words them, W:\wow-client-unpacked's GlobalStrings): asked for a
--- key, what came of a binding, and an empty slot.
B.BIND_KEY_TO_COMMAND = "Press Key to Bind to Command -> %s"
B.KEY_BOUND = "Key Bound Successfully"
B.KEY_UNBOUND_ERROR = "%s Function is Now Unbound!"
B.NOT_BOUND = "Not Bound"

--- The line a binding leaves, as WoW's frame shows it: the error (in red) when the command that had the key is left with
--- none, else that the key is bound. Returns the text and whether it is the error.
function B:BindingResult(was, unbound)
    if was and unbound then return string.format(self.KEY_UNBOUND_ERROR, self:CommandText(was)), true end
    return self.KEY_BOUND, false
end

--- A command's name as the page shows it.
function B:CommandText(command)
    local named = self.commands[command]
    if named then return named.text end
    local macro = TK.MacroBindingText and TK.MacroBindingText(command) -- s6-macros: "MACRO <reference>", by the macro's name
    if macro then return macro end -- s6-macros
    local target = command and command:match("^CLICK (.+)$")
    local f = target and _G[target]
    local info = f and self.bindable[f]
    if info then return info.name end
    -- s6-modular-g (round 20): a button of a panel that is not loaded (step 11: Modern's bars off, or in 7.x) has no
    -- frame; it is named by the panel that declares its frames (panel.clicks), as the button names itself ("Bar 1
    -- Button 11"). Text only.
    for _, panel in ipairs(target and not f and TK.Panels:All() or {}) do
        local n = panel.clicks and target:match("^" .. panel.clicks .. "(%d+)$")
        if n then return panel.name .. " Button " .. n end
    end
    return tostring(command)
end

--- The page's warnings as lines (plan D24): a key bound alone that also starts a chord (it acts on its own press
--- as usual).
function B:ChordWarningText()
    local out, map = {}, self:Map()
    for binding, command in pairs(map) do
        local first = binding:match("^([^+]+)%+.+$")
        if first and map[first] then
            out[#out + 1] = B.KeyText(first) .. " is " .. self:CommandText(map[first]) .. "'s and starts the chord "
                .. B.KeyText(binding) .. " (" .. self:CommandText(command) .. ")."
        end
    end
    table.sort(out)
    return out
end

function Mode:OnKey(key)
    local bare = U.BareKey(key)
    local frame, info = hoveredBindable()
    if bare == "ESCAPE" then
        if frame then
            local refused = unbindAll(info.command)
            if refused then self:Status(refused, 1, 0.25, 0.25) else self:Status(info.name .. ": binding cleared") end
        else
            self:Disable()
        end
        return true
    end
    if not frame then return true end
    -- Modifier keys alone never arrive here; the key with its modifiers becomes the button's primary key (its secondary
    -- stays), and the line says what came of it, as the Key Bindings page does (s6-ui-bars).
    local refused = B:GlobalRefusal(info.command, key) -- the owner's hotfix: another interface's global key
    if refused then
        self:Status(refused, 1, 0.25, 0.25)
        return true
    end
    local text, unbound = B:BindingResult(B:SetSlot(info.command, 1, key))
    self:Status(unbound and text or (info.name .. ": " .. B.KeyText(key) .. ". " .. text),
        unbound and 1 or 0.6, unbound and 0.25 or 0.9, unbound and 0.25 or 0.6)
    return true
end

-- ----- key dispatch (from C#) -----

-- Escape's cancels (core/escape.lua): the world's bow draw (order 10) and map selection (20) come first when they
-- exist; then an action held on the cursor, then an open drop-down list.
TK.Escape:AddCancel("cursor", 30, function()
    if not TK.Cursor.held then return false end
    ClearCursor()
    return true
end)
TK.Escape:AddCancel("dropdown", 40, function() return W.CloseDropdowns() end)

function B:OnKey(key, down)
    local bare = U.BareKey(key)
    -- s6-ui-login: the login screen's picture book takes its page keys first (core/login.lua, TK.LoginKeyHook).
    if down and TK.LoginKeyHook and TK.LoginKeyHook(key) then return true end
    -- s6-rules-dialogs: while an original dialog takes the keys (a modal one, a dimmer, the world map), every key-down
    -- is the dialog model's, at the menu too (components/dialogs).
    if down and TK.DialogKeyHook and TK.DialogKeyHook(key) then return true end
    -- Our notice/question keeps its keys too; passing one to UserPane (0x005A5BD0) sends a command behind it.
    -- Changing this ownership changes what the server sees.
    if down and W.QuestionShown() then
        if bare == "ESCAPE" then return TK.HandleEscape() end
        return true
    end
    -- s6-modular-g round 22: 4a's modal dialog above has every key before editing/capture modes
    -- (EventDispatcher::DispatchEvent 0x004A7130). Reordering these changes the dialog answer on the wire.
    if Mode.capture then return Mode:OnCaptureKey(key, down) end
    if down and Mode.active then return Mode:OnKey(key) end
    -- s6-ui-settings: the settings window's ordered list takes Up and Down for its chosen row (core/settings.lua), after
    -- a dialog that has the keys (Astra's review).
    if down and TK.SettingsKeyHook and TK.SettingsKeyHook(key) then return true end
    if down and bare == "ESCAPE" then return TK.HandleEscape() end
    -- s6-input (the head's note of 2026-10-06): while our settings window has the focus (TK.Settings:HasFocus), its keys
    -- are its own (its list's arrows and Escape above; a box's never come here) and no binding runs: no command, no
    -- Classic key, no Edit Mode nudge. A key held from before lets go of its command without running its release (a bar
    -- button's pushed look goes; it clicks nothing). WIRE: a binding here runs as 4a's game keys would
    -- (UserPane::HandleKeyOrTextEvent 0x005A5BD0) and may send (a spell, an item, a window's request); the original has no
    -- such window, so a key on it sends nothing. Changing this changes what the server sees.
    if TK.Settings and TK.Settings:HasFocus() then
        if down then return true end
        local command = self.held[bare]
        self.held[bare] = nil
        local target = command and command:match("^CLICK (.+)$")
        if target and _G[target] then _G[target]:SetButtonState("NORMAL") end
        return command ~= nil
    end
    if not TK.GameState:InWorld() and down then
        -- s6-interface-5x (round 13's hotfix): outside the world only a command marked atLogin acts (the interface switch
        -- keys: TK.Interfaces:SwitchTo, which says when it cannot); every other key stays the login screen's. Wire: nothing
        -- is sent there by a key (4a's title screen takes the arrows and Enter alone, MainMenuPane::HandleKeyOrTextEvent
        -- 0x004F6BF0; the game's keys are UserPane::HandleKeyOrTextEvent's, 0x005A5BD0, made at the login's
        -- InitializeMainUiGraph 0x004F7D10), and a switch sends nothing; changing this changes what the server sees.
        local c = self.commands[self:Map()[key] or ""]
        if not (c and c.atLogin and c.fn) then return false end
        TK.SafeCall(c.fn)
        return true
    end
    if TK.EditMode:OnKey(key, down) then return true end
    -- s6-devtools (round 3): Detached Camera's keys move the view (components/debug) and no other key runs its binding;
    -- while it is on every key is the UI's (C#'s Bootstrap.UiKeysNow), so the game's own keys reach no rule. WIRE: 4a has
    -- no detached view, so nothing may be sent for these keys; moving this hook after the bindings below would let a
    -- binding act (and send: a spell or item key's packet, a command, as 4a's UserPane::HandleKeyOrTextEvent 0x005A5BD0
    -- would for that key) while the view is detached, which changes what the server sees.
    if TK.DebugKeyHook and TK.DebugKeyHook(key, down) then return true end

    if down then
        -- Classic commands (opt-in) own their keys before any binding (plan D19).
        if self.keyHook and self.keyHook(key) then return true end
        local command = self:Map()[key]
        if not command then return false end
        self.held[bare] = command
        return runCommand(command, true)
    else
        local command = self.held[bare]
        if not command then return false end
        self.held[bare] = nil
        return runCommand(command, false)
    end
end

-- ----- the logic's own commands (plan D24, head note 31; s6-input) -----
--
-- Walking (W, A, S and D by default, as the original's arrows, with Shift too), the view shift (Ctrl with them: the
-- original's Ctrl+arrow, 82), the target keys (the original's Tab and v, with their modifiers) and the map's two
-- buttons (select and act; walk and look). Each posts the record of the original's key, so they run nothing here. A key
-- the rules would read as an arrow, Tab or v does nothing unless it is bound to one of these.

B.builtins = {
    { "MOVEUP", "Walk Up", "W" },
    { "MOVEDOWN", "Walk Down", "S" },
    { "MOVELEFT", "Walk Left", "A" },
    { "MOVERIGHT", "Walk Right", "D" },
    { "VIEWUP", "Shift the View Up (82)", "CTRL-W" },
    { "VIEWDOWN", "Shift the View Down (82)", "CTRL-S" },
    { "VIEWLEFT", "Shift the View Left (82)", "CTRL-A" },
    { "VIEWRIGHT", "Shift the View Right (82)", "CTRL-D" },
    { "SELECTNEXT", "Target: the original's Tab", "TAB" },
    { "SELECTPREVIOUS", "Target: the original's Shift+Tab", "SHIFT-TAB" },
    { "SELECTSELF", "Target: the original's Ctrl+Tab", "CTRL-TAB" },
    { "SELECTTOGGLE", "Target: the original's v", "V" },
    { "SELECTTOGGLEBACK", "Target: the original's V", "SHIFT-V" },
    { "SELECTFILTER", "Target: the original's Ctrl+v", "CTRL-V" },
    { "MOUSESELECT", "Map: Select and Act (left button)", "BUTTON1" },
    { "MOUSEWALK", "Map: Walk and Look (right button)", "BUTTON2" },
}
B.builtin = {}
for _, b in ipairs(B.builtins) do
    B.builtin[b[1]] = true
    B:RegisterCommand(b[1], b[2], function() end, nil, nil, true)
    TK.DB.defaultBindings[b[3]] = b[1]
end
-- A profile of version 1 had walking at most (and one made before round 8, or imported, not even that): these get
-- their default keys once, where the command is bound nowhere and the key is free (core/db.lua).
TK.DB.bindingsNewIn2 = {}
for _, b in ipairs(B.builtins) do TK.DB.bindingsNewIn2[b[1]] = true end

--- Tells C# the table: a CLICK binding runs its button's action, an action command its action, a builtin command is the
--- logic's own, a command with an up function acts on the release too, any other command nothing (the key is still
--- Lua's: its binding runs when the game did not take it).
function B:PushKeys()
    local layer = {}
    for key, command in pairs(self:Map()) do
        local target = command:match("^CLICK (.+)$")
        local c = self.commands[command]
        if c and self:Inert(c) then
            -- inert (B:Inert): no entry, as an unbound key
        elseif c and c.builtin then
            layer[key] = { builtin = command }
        elseif target then
            local f = _G[target]
            if type(f) == "table" and f.__h then layer[key] = f end
        elseif c and c.action then
            layer[key] = c.action
        elseif c and c.up then
            layer[key] = { release = true }
        elseif command:sub(1, 6) == "MACRO " then
            layer[key] = { macro = command:sub(7) } -- s6-macros: the host makes the descriptor from the macro's text
        else
            layer[key] = false
        end
    end
    TK.Actions:SetKeyLayer("bindings", layer)
end

-- ----- presets (Classic commands) and the bindings page's checks -----

--- Writes a preset (binding -> command) into a binding table: each command it names loses its other bindings first
--- (the preset's arrows walk, and W, A, S and D stop walking), except those keeps(command) keeps (s6-ui-core: the panels'
--- other keys). s6-input (round 35): apart from B:ApplyPreset, for Classic's migration of an older preset.
function B:WritePreset(map, preset, keeps)
    local named = {}
    for _, command in pairs(preset) do
        if not (keeps and keeps(command)) then named[command] = true end
    end
    for key, command in pairs(map) do
        if named[command] then map[key] = nil end
    end
    for key, command in pairs(preset) do map[key] = command end
end

--- Writes a preset into the table, visibly (B:WritePreset). Returns the table as it was, and its secondary keys' marks
--- (s6-ui-bars, review r1 P2: the slots' order goes with the bindings), for RestorePreset.
function B:ApplyPreset(preset, keeps)
    -- the owner's hotfix (Astra's after-review, P1 1): the table kept is the profile's own, without the other interfaces'
    -- global keys, which are laid over the preset again
    self:LiftGlobals()
    local map = self:Map()
    local saved, savedSecondary = U.Copy(map), U.Copy(self:Secondary())
    self:WritePreset(map, preset, keeps)
    self:ApplyGlobals()
    TK.DB:MarkDirty()
    TK.FireEvent("UPDATE_BINDINGS")
    return saved, savedSecondary
end

--- Puts back the table a preset replaced, with its secondary keys' marks (s6-ui-bars, review r1 P2).
function B:RestorePreset(saved, savedSecondary)
    self:LiftGlobals() -- the owner's hotfix: the kept table back, then the global keys over it again
    local map, second = self:Map(), self:Secondary()
    for key in pairs(map) do map[key] = nil end
    for key, command in pairs(saved or {}) do map[key] = command end
    for key in pairs(second) do second[key] = nil end
    for key, on in pairs(savedSecondary or {}) do
        if on == true and map[key] then second[key] = true end
    end
    self:ApplyGlobals()
    TK.DB:MarkDirty()
    TK.FireEvent("UPDATE_BINDINGS")
end

TK.On("PLAYER_LOGIN", function() B:PushKeys() end)
TK.On("UPDATE_BINDINGS", function() B:PushKeys() end)
TK.On("TK_PROFILE_CHANGED", function() B:PushKeys() end)

--- True if no bound key is held down (tests check that releases are never lost).
function B:NothingHeld() return next(self.held) == nil end

-- s6-modular-g round 22: EventMan::ResetInputState (0x004A90D0) clears held keys on
-- deactivation. Clear the pushed look without running release actions (the wheel's pick);
-- running a release here would change what the server sees.
TK.On("INPUT_FOCUS_LOST", function()
    for _, command in pairs(B.held) do
        local target = command:match("^CLICK (.+)$")
        if target and _G[target] then _G[target]:SetButtonState("NORMAL") end
    end
    B.held = {}
end)

--- s6-interface-5x (round 14, the separation's step 10; interface-separation.md 5.16): whether a key is held whose binding
--- acts on its release (a command with an up function: the action wheel's pick), which an interface switch waits for
--- (core/interfaces.lua's switcher), so the release reaches the code its press ran. Wire: as 4a gives a captured press's
--- release to the pane that captured it (EventDispatcher::DispatchEvent 0x004A7130), a release's action (the wheel's pick
--- runs a control's action, TK.Actions:RunFrame) goes where its press went; a switch inside the press would change what
--- the release sends. Changing this changes what the server sees.
function B:HeldForRelease()
    for _, command in pairs(self.held) do
        local c = self.commands[command]
        if c and c.up then return true end
    end
    return false
end

--- Lets go of every held binding on keys for which owns(bareKey) is true (Classic commands taking its keys over).
function B:ReleaseOwned(owns)
    for bare, command in pairs(self.held) do
        if owns(bare) then
            self.held[bare] = nil
            runCommand(command, false)
        end
    end
end
