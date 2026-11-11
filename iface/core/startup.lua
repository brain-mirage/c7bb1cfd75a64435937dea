-- Launch-only choices over the installed interfaces and settings. No alternate preset or hotkey definitions:
-- Interfaces:ApplyDefaults and the settings controls remain authoritative.
local H = __tk
local S = { overrides = {} }
TK.Startup = S

S.help = [[Startup options (for this launch only):
  -emulate <version>, -e <version>
    7 / 7x / 7.x / 7.5 / 7.5.2: the 7.x preset
    5 / 5x / 5.x / 5.3 / 5.33: the 5.x preset
    modern: the Modern preset
  -protocol <version>             An installed protocol, e.g. 5.33
  --offline                       The offline world with stand-in data once the login screen is up
  -<page>.<setting> <value>        An existing scalar setting's key or name
    e.g. -worldviewgraphics.smoothing smooth
    Quote a name containing spaces. Toggles take true or false.
  -help                          Show these options
Put overrides after -e. Put Unity/tool options before -e.
The normal menu remains available. Settings changes in this launch are temporary.
An unknown option/value ignores the startup choices and starts normally.]]

--- s6-gateway-research (round 71; interface-separation.md, G2: global code names no interface): the interface a
--- -emulate value picks, from each installed interface's own `emulate` list (interfaces/<id>/interface.lua).
local function presetFor(version)
    version = version:lower()
    for _, interface in ipairs(TK.Interfaces.list) do
        for _, alias in ipairs(interface.emulate or {}) do
            if alias == version then return interface.id end
        end
    end
end
-- MR-TK's launcher can append the saved graphics system after the player's arguments (AddGraphicsOption).
local launcherFlags = { ["-force-d3d11"] = true, ["-force-d3d12"] = true, ["-force-vulkan"] = true,
                        ["--background"] = true }

--- Parse first; nothing changes for an unknown version or an incomplete option.
function S:Read()
    local args, after = H:StartupArguments(), false
    for _, a in ipairs(args) do if a:lower() == "-help" then self.showHelp = true end end
    local i = 1
    while i <= #args do
        local arg = args[i]:lower()
        if launcherFlags[arg] then
            i = i + 1
        elseif arg == "--offline" then -- T-36 step 2 (gateway round 91): the interface page's Alone (Login:Start)
            self.offline, i = true, i + 1
        elseif arg == "--replay" then -- T-92 (gateway round 105): the editor's Replays page (Login:Start)
            self.replay, i = true, i + 1
        elseif arg == "--editor-gm" then -- T-03 part 2 (gateway round 112): the editor's GM client (Login:Start)
            self.editorGm, i = true, i + 1
        elseif arg == "-e" or arg == "-emulate" then
            local version = args[i + 1]
            self.preset = version and presetFor(version)
            if not self.preset or not TK.Interfaces:Get(self.preset) then
                return "Unknown startup preset: " .. tostring(version or "(missing)")
            end
            after, i = true, i + 2
        elseif after and arg ~= "-help" then
            local value = args[i + 1]
            if arg:sub(1, 1) ~= "-" or not value then return "Expected a setting and value after -e: " .. args[i] end
            self.overrides[#self.overrides + 1] = { name = args[i]:sub(2), text = value }
            i = i + 2
        else
            i = i + 1
        end
    end
end

--- Convert using the existing control's choices and bounds; do not call a setter until every option is valid.
local function valueFor(node, a, text)
    if a.type == "toggle" then
        if text == "true" then return true elseif text == "false" then return false end
    elseif a.type == "range" then
        local value = tonumber(text)
        local min, max = TK.Settings.RangeEnds(node, a) -- s6-ui-core (round 149): functions for the Layout offsets
        if value and (value == (a.stop and a.stop.value) or (value >= min and value <= max)) then return value end
    elseif a.type == "select" or a.type == "oneof" then
        local choices = type(a.values) == "function" and a.values() or a.values or {}
        for _, choice in ipairs(choices) do
            if tostring(choice.value) == text and not choice.disabled then return choice.value end
        end
    elseif a.type == "input" then
        return text
    end
end

--- Match the first control, exactly as Settings:SetOption does; names may themselves contain dots. Gives its page's id,
--- its key, the control and its page.
local function controlFor(nodes, name)
    for _, node in ipairs(nodes) do
        local prefix = node.id .. "."
        if name:sub(1, #prefix) == prefix then
            local key = name:sub(#prefix + 1)
            for _, tab in ipairs(node.tabs or {}) do
                for _, a in ipairs(TK.Settings.Controls(tab)) do
                    if a.key == key or a.name == key then return node.id, key, a, node end
                end
            end
        end
    end
end

function S:Resolve()
    local nodes = TK.Settings:AllNodes()
    for _, o in ipairs(self.overrides) do
        if o.name == "protocol" then
            local found = false
            for version in H:GetProtocolVersions():gmatch("[^;]+") do if version == o.text then found = true end end
            if not found then return "Unknown protocol: " .. o.text .. " (installed: " .. H:GetProtocolVersions() .. ")" end
            o.protocol = o.text
        else
            local page, key, a, node = controlFor(nodes, o.name)
            o.value = a and valueFor(node, a, o.text)
            o.page, o.key = page, key
            if o.value == nil then return "Unknown startup setting or value: -" .. o.name .. " " .. o.text end
        end
    end
end

--- Load the preset through the ordinary defaults path. On any unknown choice, restore the saved startup instead.
function S:Load()
    H.TemporarySettings = false
    H:SetLaunchProtocol(nil) -- s6-ui-core (round 121): the protocol through __tk (LuaApi.Protocol.cs)
    local problem = self:Read()
    if not problem and not self.preset then
        TK.DB:Load(TK.Interfaces:ProfileName())
        return
    end
    local machine, active = TK.Util.Copy(TK.Machine:Get()), TK.Interfaces.active
    if not problem then
        self.active = true
        H.TemporarySettings = true
        TK.Interfaces.active = self.preset
        local m = TK.Machine:Get()
        m.interface = self.preset
        m.originalScreens = (TK.Interfaces:Get(self.preset).login or {}).screens ~= nil
        m.globalBindings = {}
        self.loadingPreset = true
        TK.DB:Load(TK.Interfaces:ProfileName())
        self.loadingPreset = false
        problem = self:Resolve()
    end
    if problem then
        self.active, self.preset, self.overrides = false, nil, {}
        H.TemporarySettings = false
        TK.Machine.store.data, TK.Interfaces.active = machine, active
        TK.Machine.changes = TK.Machine.changes + 1 -- round 153: the settings put back (machine.lua's count)
        self.message = problem .. ". Starting with your saved settings. Use -help for startup options."
        TK.DB:Load(TK.Interfaces:ProfileName())
    end
end

--- After panels exist, use their ordinary settings setters, before Login:Start draws the login screen.
function S:Apply()
    if not self.active then return end
    for _, o in ipairs(self.overrides) do
        if o.protocol then H:SetLaunchProtocol(o.protocol)
        else TK.Settings:SetOption(o.page, o.key, o.value, true) end
    end
end

function S:Notice()
    if self.message then H:LogWarning(self.message) TK.Popup(self.message, "Startup options") end
    if self.showHelp then H:Log(self.help) TK.Popup(self.help, "Startup options") end
end
