-- The Plugins pages (s6-sandbox round 10; the owner, 2026-10-01), the settings list's Plugins tab (s6-ui-settings, the
-- owner, 2026-10-02):
--
--   Global        at the top the switch "Enable unsafe plugins" (kept for this computer, off by default; turning it on
--                 asks first), then every installed plugin as WoW's AddOns list shows it: a box to enable or disable it
--                 at the next reload, its title and version, a mark when it uses unsafe calls, its author, notes and
--                 state; Enable All, Disable All and Reload. Listed at the login screen too. It was the Plugin List
--                 until the nested menus (s6-ui-settings; the owner's Plugins tree, 2026-10-03: the global settings
--                 for plugins first, with the remote protocol's pages under them).
--   <a plugin>    each installed plugin by its title, as WoW lists addons by name: its options panel's page (Settings)
--                 when it is running with one (C_Options.RegisterPanel), and an About page (name, version, author,
--                 notes, enabled and state). The pages the plugin titles (C_Options.RegisterPanel(options, title):
--                 s6-ui-settings, the owner's nested settings menus) go under it, each by its title.
--
-- The mod host answers through C:Host() (Sandbox/PluginsPage.cs); a panel's values are asked of the plugin each time,
-- and a plugin's state is read again at each refresh.

local C = TK.GetComponent("plugins")
local W = TK.UI

local CONSENT = __tk:IsPublicTest() and "Plugins may connect to other clients. Install only plugins you trust." or "Plugins will be able to open a network port on this PC, talk directly to other players' clients, and "
    .. "run commands on this client that those players send. Install only plugins you trust."

-- Yes answers only once the dialog has been up this long (seconds), so no click aimed at something under it lands on it.
local CONSENT_DELAY = 1

local function refresh()
    if TK.Settings:IsOpen() then TK.Settings:RefreshPage() end
end

--- The consent (review r10, finding 1): the client's own dialog, above every frame there is. No plugin frame reaches
--- FULLSCREEN_DIALOG or TOOLTIP (Sandbox/ModApi.cs, TopStrata), and the consent sits at TOOLTIP above the client's own
--- tooltips and menus too (review r11: a plugin's text reaches them, a minimap marker's label in GameTooltip), so nothing
--- that shows a plugin's text can cover or relabel it, and it takes the mouse first. Its Yes is the only way the switch
--- turns on: plugins run in their own states and reach no shipped frame or function, a macro's /click does nothing in
--- this game and macros have no script command, and a binding's CLICK needs a global name, which neither the dialog nor
--- its buttons have. Escape and No leave it off.
local function askConsent()
    local c = C.consent
    if not c then
        -- no global name, so no CLICK binding names it or its buttons; s6-ui-core (round 56; Astra's review): solid, a popup
        c = W.PopupPanel(W.Panel(UIParent, nil))
        c:SetFrameStrata("TOOLTIP")
        c:SetFrameLevel(900)
        c:SetWidth(440)
        c:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        c:EnableMouse(true)
        c.title = W.Label(c, "Enable unsafe plugins?", 15, W.gold)
        c.title:SetPoint("TOP", c, "TOP", 0, -16)
        c.text = W.Label(c, CONSENT, 13, W.white)
        c.text:SetWordWrap(true)
        c.text:SetWidth(400)
        c.text:SetPoint("TOP", c.title, "BOTTOM", 0, -12)
        c:SetHeight(c.text:GetStringHeight() + 104)
        c.yes = W.Button(c, "Yes", 100, 26, "red", function()
            if GetTime() - c.shownAt < CONSENT_DELAY then return end
            c:Hide()
            C:SetUnsafe(true)
            refresh()
        end)
        c.yes:SetPoint("BOTTOMRIGHT", c, "BOTTOM", -8, 16)
        c.no = W.Button(c, "No", 100, 26, nil, function() c:Hide() end)
        c.no:SetPoint("BOTTOMLEFT", c, "BOTTOM", 8, 16)
        c:SetScript("OnUpdate", function() c.yes:SetEnabled(GetTime() - c.shownAt >= CONSENT_DELAY) end)
        c:Hide()
        TK.Escape:AddWindow(c, function() c:Hide() end)
        C.consent = c
    end
    c.shownAt = GetTime()
    c.yes:SetEnabled(false)
    c:Show()
end

local function setSwitch(_, on)
    if on then askConsent() else C:SetUnsafe(false) end
end

local function switchState()
    if __tk:IsPublicTest() then return C:Machine().unsafe and "On: plugins may connect to other clients." or "Off: unsafe calls are refused." end
    if C:Machine().unsafe then
        return "On: plugins may open the peer channel's port, send to other players' clients and run commands on them, "
            .. "and commands from those players run here."
    end
    return "Off: every unsafe call is refused, the peer channel neither listens nor connects, and commands from other "
        .. "players' clients are dropped."
end

--- A plugin's line under its box: its author and notes, then its state and mark as they are now (review r10, finding 4).
local function pluginText(h, p)
    local by = p.author ~= "" and ("By " .. p.author .. ". ") or ""
    local notes = p.notes ~= "" and (p.notes .. "\n") or ""
    return function()
        local unsafe = p.unsafe or h:TriedUnsafe(p.name)
        return by .. notes .. h:State(p.name) .. (unsafe and "  (Uses unsafe calls.)" or "")
    end
end

local function listArgs()
    local args = {
        { type = "toggle", name = "Enable unsafe plugins", width = "full",
          get = function() return C:Machine().unsafe end, set = setSwitch },
        { type = "description", name = switchState },
        { type = "header", name = "Installed Plugins" },
    }
    local h = C:Host()
    if not h then
        args[#args + 1] = { type = "description", name = "Plugins do not run in this client." }
        return args
    end
    local list = h:List()
    if #list == 0 then
        -- s6-ui-core (round 32): inside the Lua folder, where ModHostDriver.cs:42 reads them (the text said "beside").
        args[#args + 1] = { type = "description", name = "No plugins are installed (the mods folder inside the client's Lua folder: lua\\mods)." }
    end
    for _, p in ipairs(list) do
        local name = p.title .. (p.version ~= "" and ("  " .. p.version) or "") .. (p.unsafe and "  [unsafe]" or "")
        args[#args + 1] = { type = "toggle", name = name, width = "full",
                            get = function() return not C:Machine().disabled[p.name] end,
                            set = function(_, on) C:SetEnabled(p.name, on) end }
        args[#args + 1] = { type = "description", id = "state:" .. p.name, name = pluginText(h, p) }
    end
    args[#args + 1] = { type = "break" }
    args[#args + 1] = { type = "description", name = "Enabling or disabling a plugin takes effect at the next reload." }
    args[#args + 1] = { type = "execute", name = "Enable All", func = function() C:SetEnabled(nil, true) end }
    args[#args + 1] = { type = "execute", name = "Disable All", func = function() C:SetEnabled(nil, false) end }
    args[#args + 1] = { type = "execute", name = "Reload", func = function() ReloadUI() end }
    return args
end

--- A plugin's panel, as settings args whose values are the plugin's, by page in the plugin's order: { { title, args },
--- ... }, title nil for the plugin's own page (s6-ui-settings: a titled page goes under the plugin in the list). Each
--- control names its option by its page and its index on that page (Astra's review of round 17), so a page the plugin
--- registers again, longer or shorter, never moves the controls of another page shown meanwhile.
local function panelPages(h, name)
    local pages, byTitle = {}, {}
    for _, o in ipairs(h:Options(name)) do
        local key = o.page or false
        if not byTitle[key] then
            byTitle[key] = { title = o.page, args = {} }
            pages[#pages + 1] = byTitle[key]
        end
        local args, page = byTitle[key].args, o.page
        local i = #args + 1   -- the option's index on its page: one arg per option
        local function value() return h:Get(name, i, page) end
        if o.type == "header" then
            args[i] = { type = "header", name = o.name or tostring(value() or "") }
        elseif o.type == "description" then
            args[i] = { type = "description", name = o.name or function() return tostring(value() or "") end }
        elseif o.type == "toggle" then
            args[i] = { type = "toggle", name = o.name, width = "full", get = function() return value() == true end,
                        set = function(_, on) h:Set(name, i, on, page) end }
        elseif o.type == "input" then
            args[i] = { type = "input", name = o.name, set = function(_, text) h:Set(name, i, text, page) end }
        elseif o.type == "execute" then
            args[i] = { type = "execute", name = o.name, func = function() h:Set(name, i, nil, page) end }
        end
    end
    return pages
end

--- What a plugin is (s6-ui-settings), from what the plugin system knows of it.
local function aboutArgs(h, p)
    return {
        { type = "description", name = p.title .. (p.version ~= "" and ("  " .. p.version) or "") },
        { type = "description", name = "By " .. (p.author ~= "" and p.author or "an unnamed author") .. "." },
        { type = "description", name = p.notes ~= "" and p.notes or "No notes." },
        { type = "description", name = function()
            return (C:Machine().disabled[p.name] and "Disabled" or "Enabled") .. ". " .. h:State(p.name)
                .. ((p.unsafe or h:TriedUnsafe(p.name)) and "  (Uses unsafe calls.)" or "")
        end },
        { type = "description", name = "Its folder: " .. p.name .. ". Enable or disable it on Plugins, Global." },
    }
end

function C:SettingsNodes()
    local nodes = { {
        id = "plugins", title = "Global", category = "plugins", order = self.order, atLogin = true, machine = true,
        noReset = true, -- the installed plugins and the player's choices
        db = function() return C:Machine() end,
        tabs = { { name = "Plugins", args = listArgs() } },
    } }
    local h = self:Host()
    if not h then return nodes end
    for i, p in ipairs(h:List()) do
        local id = "plugin:" .. p.name
        local tabs = { { name = "About", args = aboutArgs(h, p) } }
        nodes[#nodes + 1] = { id = id, title = p.title, category = "plugins", order = 910, sub = i,
                              machine = true, noReset = true, tabs = tabs } -- a panel's values are the plugin's own
        for j, page in ipairs(p.panel and panelPages(h, p.name) or {}) do
            if not page.title then
                table.insert(tabs, 1, { name = "Settings", args = page.args })
            else
                -- s6-ui-settings (the owner's nested settings menus: "Plugin X / -- General plugin x settings / --
                -- additional x"): a page the plugin titled (C_Options.RegisterPanel's title), under the plugin.
                nodes[#nodes + 1] = { id = id .. ":" .. page.title, title = page.title, parent = id, category = "plugins",
                                      order = 910, sub = i + j / 1000, machine = true, noReset = true,
                                      tabs = { { name = page.title, args = page.args } } }
            end
        end
    end
    return nodes
end
