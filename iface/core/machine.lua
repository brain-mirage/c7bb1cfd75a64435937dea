-- Machine settings: what belongs to this computer rather than to a layout (the head's answer to question 1).
-- They live in the player's config/machine.json, next to the profiles:
--
--   uiScaleAuto, uiScale   the global UI scale; automatic (fit to the screen's height) until the user sets it
--   grid, gridSize, snap   edit-mode preferences, which depend on the monitor
--   showRecent, recentAccounts   the login screen's recent account names (never passwords)
--   disableLoginAnimations   s6-ui-login (round 10): the login screen's scene holds one moment of the night
--   effectOverrides        effect name -> "buff" | "debuff", set by right-clicking an effect icon
--   graphics, sound        preferences for later; stored now so the settings pages exist before the world
--   server                 the login server's address (host, port), set on the login screen
--   (ignored               before s6-layout round 5: each name's ignore list; it is the character's now, in its store
--                          on its server, carried there once at the start: TK.Core.Settings.CharacterCarryOver)
--   plugins                s6-sandbox (round 10): the Plugins page's unsafe switch and disabled plugins (components/plugins)
--
-- What the original kept in the registry and these pages show lives in settings.toml (plan 5.14, head note 17;
-- imported once from the original): the last account name (login.account, the first recent account) and the sound
-- switches and volumes (sound.effects, effects_volume, music, music_volume). It is read when the machine settings
-- load, and written back whenever they are saved.

local H = __tk
local U = TK.Util
local V = TK.Validate

local M = {}
TK.Machine = M

M.defaults = {
    version = 1,
    uiScaleAuto = true,
    uiScale = 1,
    grid = false,
    gridSize = 32,
    snap = true,
    showRecent = true,
    disableLoginAnimations = false,
    recentAccounts = {},
    effectOverrides = {},
    -- s6-ui-core (round 54): advanced, Graphics > Advanced's Enable Advanced Graphics
    graphics = { windowMode = "windowed", vsync = false, frameCap = 60, windowWidth = 0, displaySeeded = false, advanced = true },
    sound = { master = 1, music = 0.7, effects = 0.8 },
    server = { host = "127.0.0.1", port = 3000 },
    -- s6-modular-g (interfaces, phase 2): the interface (applies at the next start, core/interfaces.lua; none until the
    -- player chooses one: the default interface, TK.Interfaces:Default, s6-interface-5x round 15) and the profile last
    -- used with each interface
    interfaceProfiles = {},
    profileInterfaces = {},
    -- s6-interface-5x (round 11): the profiles an interface's Reset marked, which load as new (core/db.lua's Load)
    resetProfiles = {},
}

M.rules = {
    uiScale = { min = 0.5, max = 2 },
    gridSize = { min = 8, max = 128 },
    frameCap = { min = 20, max = 240, stop = 0 }, -- round 58 (head note 024): 0 is "Unlimited", the slider's end stop
    master = { min = 0, max = 1 },
    music = { min = 0, max = 1 },
    effects = { min = 0, max = 1 },
    windowMode = { allowed = { windowed = true, borderless = true, fullscreen = true } },
    windowWidth = { min = 0, max = 3840 },
    port = { min = 1, max = 65535 },
}

-- s6-gateway round 39 (head note 113): machine.json's write is queued on the files thread unless now (store.lua).
M.store = TK.NewStore("The machine settings", function(data, now)
    local ok = M:WriteClientSettings(data)
    return H:MachineSave(data, now) and ok
end, "machine")
table.insert(TK.Stores, M.store)

--- Account names: at most 15 characters, as the original allows.
function M.IsAccountName(s) return type(s) == "string" and #s >= 1 and #s <= 15 and s:match("^[%w_%-]+$") ~= nil end

function M:Normalize(m)
    local problems = {}
    if type(m) ~= "table" then
        if m ~= nil then problems[1] = "machine" end
        m = {}
    end
    local out = {}
    for k, v in pairs(m) do out[k] = v end
    -- s6-modular-g (round 11): the interfaces were "themes" until round 11; a file saved before keeps its choices under
    -- the new keys (the old ones are dropped at its next save).
    if out.interface == nil then out.interface = out.theme end
    out.interfaceProfiles = out.interfaceProfiles or out.themeProfiles
    out.profileInterfaces = out.profileInterfaces or out.profileThemes
    out.theme, out.themeProfiles, out.profileThemes = nil, nil, nil
    local recent, overrides = out.recentAccounts, out.effectOverrides
    local interfaceProfiles, profileInterfaces = out.interfaceProfiles, out.profileInterfaces
    local resetProfiles = out.resetProfiles
    out.recentAccounts, out.effectOverrides, out.interfaceProfiles, out.profileInterfaces = nil, nil, nil, nil
    out.resetProfiles = nil
    V.NormalizeLike(out, { version = 1, uiScaleAuto = true, uiScale = 1, grid = false, gridSize = 32, snap = true,
                           showRecent = true, disableLoginAnimations = false, graphics = self.defaults.graphics,
                           sound = self.defaults.sound,
                           server = self.defaults.server },
        self.rules, "machine", problems)
    -- s6-modular-g (interfaces, phase 2): interface id -> profile name, and profile name -> interface id
    out.interfaceProfiles, out.profileInterfaces = {}, {}
    for id, name in pairs(type(interfaceProfiles) == "table" and interfaceProfiles or {}) do
        if type(id) == "string" and type(name) == "string" and H:ProfileIsValidName(name) then out.interfaceProfiles[id] = name end
    end
    for name, id in pairs(type(profileInterfaces) == "table" and profileInterfaces or {}) do
        if type(id) == "string" and type(name) == "string" and H:ProfileIsValidName(name) then out.profileInterfaces[name] = id end
    end
    -- s6-interface-5x (round 11): profile name -> true, the profiles to load as new
    out.resetProfiles = {}
    for name, marked in pairs(type(resetProfiles) == "table" and resetProfiles or {}) do
        if marked == true and type(name) == "string" and H:ProfileIsValidName(name) then out.resetProfiles[name] = true end
    end
    out.recentAccounts = V.StringList(recent, problems, "machine.recentAccounts", M.IsAccountName, 8)
    out.effectOverrides = {}
    if type(overrides) == "table" then
        for name, kind in pairs(overrides) do
            if type(name) == "string" and #name <= 64 and (kind == "buff" or kind == "debuff") then
                out.effectOverrides[name] = kind
            else
                problems[#problems + 1] = "machine.effectOverrides." .. tostring(name)
            end
        end
    elseif overrides ~= nil then
        problems[#problems + 1] = "machine.effectOverrides"
    end
    return out, problems
end

function M:Load()
    local m, status = H:MachineLoad()
    local fresh = m == nil
    if status:sub(1, 12) == "quarantined|" then
        local file = status:match("^quarantined|([^|]*)|")
        TK.Popup("The machine settings could not be read. They were kept as " .. tostring(file)
            .. " and the defaults are used.", "Settings recovered")
    end
    local data, problems = self:Normalize(m)
    if not fresh and #problems > 0 then
        local copy = H:MachineBackup("invalid")
        TK.Popup("Some machine settings were invalid and were reset (" .. table.concat(problems, ", ", 1, math.min(#problems, 6))
            .. "). The original file is kept as " .. tostring(copy) .. ".", "Settings recovered")
        H:LogWarning("machine settings: invalid " .. table.concat(problems, ", "))
    end
    self.store.data = data
    self.fresh = fresh
    self:ReadClientSettings()
    if fresh or #problems > 0 then self.store:MarkDirty() end
end

-- ----- settings.toml -----

local function percent(v) return math.floor(U.Clamp(v or 0, 0, 1) * 100 + 0.5) end

--- The login screen's recent account names with name first: no name twice, at most eight. s6-optimize R62 (R-e): the
--- start's read of settings.toml and RememberAccount each built it themselves before.
local function nameFirst(list, name)
    local out = { name }
    for _, n in ipairs(list) do
        if n ~= name and #out < 8 then out[#out + 1] = n end
    end
    return out
end

function M:ReadClientSettings()
    local d = self:Get()
    local account = H:ClientSettingString("login", "account")
    if M.IsAccountName(account) and d.recentAccounts[1] ~= account then
        d.recentAccounts = nameFirst(d.recentAccounts, account)
    end
    local s = d.sound
    s.effectsOn = H:ClientSettingBool("sound", "effects")
    s.effects = U.Clamp(H:ClientSettingInt("sound", "effects_volume"), 0, 100) / 100
    s.music = H:ClientSettingBool("sound", "music") and U.Clamp(H:ClientSettingInt("sound", "music_volume"), 0, 100) / 100 or 0
    -- The original's display mode, imported (display.windowed and window_width; import.display marks an import that
    -- took it, and a windowed one shows by itself): it seeds this machine's window once (the owner's answer to round
    -- 16); the player's own choice stands after.
    local g = d.graphics
    local windowed = H:ClientSettingBool("display", "windowed")
    if not g.displaySeeded and (windowed or H:ClientSettingBool("import", "display")) then
        g.displaySeeded = true
        if windowed then
            g.windowMode = "windowed"
            g.windowWidth = U.Clamp(H:ClientSettingInt("display", "window_width"), 1024, 3840)
            self.seedWidth = g.windowWidth   -- sizes the window once; Reload UI and Graphics changes keep the player's size
        else
            g.windowMode = "borderless"   -- the original's full screen is a 1024 x 768 mode change we do not make
        end
        self.store:MarkDirty()
    end
end

function M:WriteClientSettings(d)
    H:ClientSettingSetString("login", "account", d.recentAccounts[1] or "")
    local s = d.sound
    H:ClientSettingSetBool("sound", "effects", s.effectsOn ~= false)
    H:ClientSettingSetInt("sound", "effects_volume", percent(s.effects))
    -- Music at 0 is the original's music switched off; its volume is kept for when it comes back on.
    -- s6-audio hook: the saved switch is Config's "Music", the audio logic's flag (the music switch, and the MIDI
    -- player's Disable and Enable from F7 and the window's focus write it); the volume's without the audio component.
    local musicOn = (s.music or 0) > 0
    local Sound = TK.Game and TK.Game.Sound -- (core/game/sound.lua: loaded after this file)
    if Sound then musicOn = Sound.MusicOn() end
    H:ClientSettingSetBool("sound", "music", musicOn)
    -- s6-audio hook: the volume saved is the audio logic's playback volume, kept while the slider shows the music off.
    local musicLevel = (s.music or 0) > 0 and s.music or nil
    if Sound then musicLevel = Sound.MusicVolume() or musicLevel end
    if musicLevel then H:ClientSettingSetInt("sound", "music_volume", percent(musicLevel)) end
    return H:ClientSettingsSave()
end

function M:Get() return self.store.data end
function M:MarkDirty() self.store:MarkDirty() end

--- The UI scale that fits the screen: 1.0 at 1080 pixels high, in proportion to the height, clamped.
function M:AutoScale()
    local physicalHeight = GetScreenHeight() * TK.UIScale()
    return U.Clamp(U.Round(physicalHeight / 1080, 0.05), 0.5, 2)
end

function M:EffectiveUIScale()
    local d = self:Get()
    if d.uiScaleAuto then return self:AutoScale() end
    return d.uiScale
end

--- Applies the UI scale (automatic or the user's).
function M:ApplyUIScale()
    TK.SetUIScale(self:EffectiveUIScale())
end

--- The user set a scale: automatic scaling stops.
function M:SetUIScale(v)
    local d = self:Get()
    d.uiScaleAuto = false
    d.uiScale = U.Clamp(v, 0.5, 2)
    self:MarkDirty()
    self:ApplyUIScale()
end

function M:SetUIScaleAuto(on)
    self:Get().uiScaleAuto = on and true or false
    self:MarkDirty()
    self:ApplyUIScale()
end

--- Applies the Graphics settings: window mode, vertical sync, frame cap, and the imported window width when it was
--- just seeded (s6-ui-core round 31: before, every UI load sized the window back to it, un-maximizing it).
--- s6-ui-core (round 54): whether the advanced graphics settings (Graphics > Advanced) have an effect.
function M:AdvancedGraphics() return self:Get().graphics.advanced ~= false end

function M:ApplyGraphics()
    local g = self:Get().graphics
    local width = self.seedWidth or 0
    self.seedWidth = nil
    H:ApplyGraphics(g.windowMode, g.vsync and true or false, math.floor(g.frameCap), math.floor(width))
    self:ApplyGraphicsEngine()
end

--- s6-reprojection (round 63; the graphics plan, section 7): Enable New Graphics Engine (Experimental > Misc), told to
--- the world renderers, which swap engines at once. Drawing only: nothing is sent.
function M:ApplyGraphicsEngine()
    CS.TK.Modular.Draw.WorldRenderers.SetNewEngine(self:Get().newGraphicsEngine == true)
end

--- Remembers an account name for the login screen's recent list (most recent first). Never a password.
function M:RememberAccount(name)
    if not M.IsAccountName(name) then return end
    self:Get().recentAccounts = nameFirst(self:Get().recentAccounts, name)
    self:MarkDirty()
end

TK.On("DISPLAY_SIZE_CHANGED", function()
    if M:Get() and M:Get().uiScaleAuto then M:ApplyUIScale() end
end)
