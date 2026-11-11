-- The client's side of the Plugins pages (s6-sandbox round 10): what the mod host reads at its start and after each
-- reload (Sandbox/ModHostDriver.cs), and what the pages change on it at once (TK_PluginHost, Sandbox/PluginsPage.cs).
--
--   TK.PluginSettings()   the "Enable unsafe plugins" switch, and the disabled plugins' names (space-separated)

local C = TK.GetComponent("plugins")

--- The machine settings' plugins table (kept for this computer): unsafe (off by default), disabled (name -> true).
function C:Machine()
    local m = TK.Machine:Get()
    local p = type(m.plugins) == "table" and m.plugins or {}
    m.plugins = p
    if type(p.unsafe) ~= "boolean" then p.unsafe = false end
    if type(p.disabled) ~= "table" then p.disabled = {} end
    return p
end

--- The mod host's view for the pages; nil in a client without plugins.
function C:Host() return rawget(_G, "TK_PluginHost") end

function TK.PluginSettings()
    local p = C:Machine()
    local names = {}
    for name, off in pairs(p.disabled) do
        if off == true and type(name) == "string" then names[#names + 1] = name end
    end
    table.sort(names)
    return p.unsafe, table.concat(names, " ")
end

--- The player's switch: kept, and on the host at once.
function C:SetUnsafe(on)
    self:Machine().unsafe = on
    TK.Machine:MarkDirty()
    local h = self:Host()
    if h then h:SetUnsafeAllowed(on) end
    -- s6-optimize (round 33): the Remote-Protocol pages under it follow (peer's shown(): the protocol needs this switch)
    if TK.Settings then TK.Settings:RefreshTree() end
end

--- A plugin enabled or disabled (at the next reload), or all of them (name nil).
function C:SetEnabled(name, on)
    local p = self:Machine()
    if name then
        p.disabled[name] = (not on) or nil
    else
        local h = self:Host()
        for _, info in ipairs(h and h:List() or {}) do p.disabled[info.name] = (not on) or nil end
    end
    TK.Machine:MarkDirty()
    local h = self:Host()
    if h then h:SetDisabled(select(2, TK.PluginSettings())) end
end
