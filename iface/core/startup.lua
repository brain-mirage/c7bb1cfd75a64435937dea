-- Launch-only choices over the installed interfaces and settings. No alternate preset or hotkey definitions:
-- Interfaces:ApplyDefaults and the settings controls remain authoritative.
local H = __tk
local S = { overrides = {} }
TK.Startup = S
local P = CS.TK.Modular.ProtocolHost

S.help = [[Startup options (for this launch only):
  -emulate <version>, -e <version>
    7 / 7x / 7.x / 7.5 / 7.5.2: the 7.x preset
    5 / 5x / 5.x / 5.3 / 5.33: the 5.x preset
    modern: the Modern preset
  -protocol <version>             An installed protocol, e.g. 5.33
  -<page>.<setting> <value>        An existing scalar setting's key or name
    e.g. -worldviewgraphics.smoothing smooth
    Quote a name containing spaces. Toggles take true or false.
  -help                          Show these options
Put overrides after -e. Put Unity/tool options before -e.
The normal menu remains available. Settings changes in this launch are temporary.
An unknown option/value ignores the startup choices and starts normally.]]

local aliases = { ["7"] = "7x", ["7x"] = "7x", ["7.x"] = "7x", ["7.5"] = "7x", ["7.5.2"] = "7x",
                  ["5"] = "5x", ["5x"] = "5x", ["5.x"] = "5x", ["5.3"] = "5x", ["5.33"] = "5x", modern = "modern" }
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
        elseif arg == "-e" or arg == "-emulate" then
            local version = args[i + 1]
            self.preset = version and aliases[version:lower()]
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
local function valueFor(a, text)
    if a.type == "toggle" then
        if text == "true" then return true elseif text == "false" then return false end
    elseif a.type == "range" then
        local value = tonumber(text)
        if value and (value == (a.stop and a.stop.value) or (value >= a.min and value <= a.max)) then return value end
    elseif a.type == "select" or a.type == "oneof" then
        local choices = type(a.values) == "function" and a.values() or a.values or {}
        for _, choice in ipairs(choices) do
            if tostring(choice.value) == text and not choice.disabled then return choice.value end
        end
    elseif a.type == "input" then
        return text
    end
end

--- Match the first control, exactly as Settings:SetOption does; names may themselves contain dots.
local function controlFor(nodes, name)
    for _, node in ipairs(nodes) do
        local prefix = node.id .. "."
        if name:sub(1, #prefix) == prefix then
            local key = name:sub(#prefix + 1)
            for _, tab in ipairs(node.tabs or {}) do
                for _, a in ipairs(TK.Settings.Controls(tab)) do
                    if a.key == key or a.name == key then return node.id, key, a end
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
            for version in P.Versions():gmatch("[^;]+") do if version == o.text then found = true end end
            if not found then return "Unknown protocol: " .. o.text .. " (installed: " .. P.Versions() .. ")" end
            o.protocol = o.text
        else
            local page, key, a = controlFor(nodes, o.name)
            o.value = a and valueFor(a, o.text)
            o.page, o.key = page, key
            if o.value == nil then return "Unknown startup setting or value: -" .. o.name .. " " .. o.text end
        end
    end
end

--- Load the preset through the ordinary defaults path. On any unknown choice, restore the saved startup instead.
function S:Load()
    H.TemporarySettings = false
    P.StartupVersion = nil
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
        self.message = problem .. ". Starting with your saved settings. Use -help for startup options."
        TK.DB:Load(TK.Interfaces:ProfileName())
    end
end

--- After panels exist, use their ordinary settings setters, before Login:Start draws the login screen.
function S:Apply()
    if not self.active then return end
    for _, o in ipairs(self.overrides) do
        if o.protocol then P.StartupVersion = o.protocol
        else TK.Settings:SetOption(o.page, o.key, o.value, true) end
    end
end

function S:Notice()
    if self.message then H:LogWarning(self.message) TK.Popup(self.message, "Startup options") end
    if self.showHelp then H:Log(self.help) TK.Popup(self.help, "Startup options") end
end
