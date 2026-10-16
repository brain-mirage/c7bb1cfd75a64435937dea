-- Screenshot mode's fixed states (C# calls __tk_preview(state) and then captures the screen):
--
--   default    the default layout
--   editmode   edit mode unlocked, with its movers and the grid
--   settings   the settings window on Bar 1's General Settings
--   settingsgeneral, settingsplugins   s6-ui-settings: its list's General tab (Key Bindings) and Plugins tab (the list)
--   settingsmicromenu, settingsreset   s6-ui-settings: the Micro Menu's page with every button on in another order (the
--              bar below it), and the reset icon's question on the Minimap page
--   cooldowns  every button on Bar 1 and three items on Bar 2 cast at the same moment; C# then moves the clock
--              on 3.3 s so the sweeps are part-way round
--   world2x    the world view at 2x (21 x 19 tiles) filling the screen, showing the darkened outer ring
--   world1x    the world view at 1x with a 25 x 19 world, the whole ring visible
--   worldsmooth the world view smoothly scaled (sharp bilinear) to a larger frame
--   login      the login screen with a masked password, contacting its server (a closed local port: screenshot mode
--              never reaches a server it was not given)
--   loginfailed the same once the connection has failed: the status line counts down to the next attempt (C# waits)
--   character  the character window on its Character tab, with the side tabs
--   party      the party frames and the target frame (the target has been hit)
--   buffs      the buff and debuff frames (one unclassified effect) and the aether list with a few aethers
--   settings2x the settings window at UI scale 2 (C# first makes the window 1600 x 900)
--   login2x    the login screen at UI scale 2 with an error (C#: 1280 x 720)
--   bag        the bag with the mock items and the item menu of slot a (s6-ui-next)
--   spellbook  the character window on its Spell Book tab
--   social     the social panel on its Group page, and the emote menu
--   classic    Classic Commands on, with the original's "Eat what?" prompt
--   newchar    the New Character screen (the screen taken as connected)
--   servers    the Servers settings page at the login screen, with two saved servers
--
-- Every state but login enters the world first (the client starts on the login screen).
--
-- s6-modular-g (round 20; Astra's pass 18-3, P2): the views open and close through the game layer (TK.Game.Views, the calls
-- Modern's old openers forward to) and the slots are pressed by their carriers (TK.Game.Hotkeys), so every state runs in
-- any interface: a view shows on what the active interface draws it with, and a state's own frames of Modern's panels
-- (the bag's slot, the spell book's cell, the bars) are used only while those are loaded (interface-separation.md 5.18).
-- Screenshot mode runs offline (MockWorld, a closed local port): nothing here reaches a server.

local V, K = TK.Game.Views, TK.Game.Hotkeys

local function closeAll()
    if not TK.GameState:InWorld() then TK.Login:EnterWorld("preview") end
    TK.KeyBindMode:Disable()
    TK.Settings:Close()
    V.CloseWindows()
    TK.UI.CloseMenu()
    if TK.EditMode:IsOpen() then TK.EditMode:Close() end -- s6-ui-core (round 54): Lock leaves Edit Mode open
    ClearCursor()
    GameTooltip:Hide()
    if TKSettingsResetAsk then TKSettingsResetAsk:Hide() end -- s6-ui-settings: after "settingsreset"
    local mm = TK.GetComponent("micromenu") -- and the Micro Menu's own order after "settingsmicromenu"
    if mm and mm.previewOrder then
        mm:DB().buttons, mm.previewOrder = nil, nil
        if mm:Loaded() then mm:ApplySettings() end
    end
end

--- Presses an action slot as its key does: the original's hotkey slots by their carriers, which every interface has
--- (the same press and frozen action as Modern's bar button: K.Press, K.Attach), another by Modern's bar button while
--- its bars are loaded.
local function press(slot)
    local b = K.carriers[slot] or _G["TKActionBar" .. math.ceil(slot / 12) .. "Button" .. ((slot - 1) % 12 + 1)]
    if b then b:Click("LeftButton") end
end

local states = {}

function states.default()
    closeAll()
end

function states.editmode()
    closeAll()
    TK.Machine:Get().grid = true
    TK.EditMode:Unlock()
end

function states.settings()
    closeAll()
    TK.Machine:Get().grid = false
    TK.Settings:Open("bar1", "General Settings")
end

function states.settingsgeneral()
    closeAll()
    TK.Machine:Get().grid = false
    TK.Settings:Open("keybindings", "General")
end

function states.settingsplugins()
    closeAll()
    TK.Machine:Get().grid = false
    TK.Settings:Open("plugins")
end

function states.settingsmicromenu()
    closeAll()
    TK.Machine:Get().grid = false
    local mm = TK.GetComponent("micromenu")
    local list = mm:Buttons()
    for _, e in ipairs(list) do e.on = true end
    table.insert(list, 1, table.remove(list, 3))   -- the bag first
    mm:DB().buttons, mm.previewOrder = list, true
    if mm:Loaded() then mm:ApplySettings() end
    TK.Settings:Open("micromenu", "General Settings")
end

function states.settingsreset()
    closeAll()
    TK.Machine:Get().grid = false
    TK.Settings:Open("minimap", "General Settings")
    TK.Settings:AskReset()
end

function states.cooldowns()
    closeAll()
    for slot = 1, 12 do press(slot) end    -- Bar 1
    for slot = 13, 15 do press(slot) end   -- Bar 2's first three
end

local function world(cols, rows, scale, smoothing, fill) -- s6-world-view (round 29): the scale and smoothing
    closeAll()
    local C = TK.GetComponent("worldview")
    if not C then return end
    local db = C:DB()
    db.cols, db.rows, db.worldScale, db.smoothing, db.autoExtend = cols, rows, scale, smoothing, false -- s6-world-view (round 29)
    db.includeOuter = false -- s6-world-view (round 29)
    if fill then
        db.width, db.height = GetScreenWidth() - 40, GetScreenHeight() - 40
    else
        db.width, db.height = 0, 0
    end
    TK.DB.profile.positions.worldview = { "CENTER", "CENTER", 0, 0 }
    C:ApplySettings()
    TK.EditMode:RestoreAll()
end

function states.world2x() world(21, 19, "2", "none", true) end -- s6-world-view (round 29)
function states.world1x() world(25, 19, "1", "none", false) end -- s6-world-view (round 29)

--- Smooth scaling: a 21 x 17 world stretched to a 1400 x 1000 frame (about 1.2x) through the sharp-bilinear shader.
function states.worldsmooth()
    world(21, 17, "stretch", "smooth", false) -- s6-world-view (round 29)
    local C = TK.GetComponent("worldview")
    local db = C:DB()
    db.width, db.height = 1400, 1000
    db.includeOuter = true -- s6-world-view (round 29): the whole picture fits the frame
    C:ApplySettings()
end

--- The world view as in a new profile (the world states above change it).
local function defaultWorld()
    local C = TK.GetComponent("worldview")
    if not C then return end
    local db = C:DB()
    for k, v in pairs(C.defaults) do db[k] = v end
    TK.DB.profile.positions.worldview = nil
    C:ApplySettings()
    TK.EditMode:RestoreAll()
end

function states.login()
    closeAll()
    defaultWorld()
    for _, name in ipairs({ "bram", "cyra", "aria" }) do TK.Machine:RememberAccount(name) end
    TK.Login.account = "aria"
    TK.Login:LogOut()
    TKLoginScreen.password:SetText("secret")
end

function states.loginfailed()
    closeAll()
    TK.Login:LogOut()
end

function states.character()
    closeAll()
    V.Open("character", "input")
end

function states.party()
    closeAll()
end

function states.buffs()
    closeAll()
    local C = TK.GetComponent("auras")
    C:DB().aethers.enabled = true
    if C:Loaded() then C:ApplySettings() end
    TK.EditMode:UpdateMovers()
    for _, slot in ipairs({ 25, 26, 16 }) do press(slot) end -- Bar 3's buttons 1 and 2, Bar 2's 4
end

function states.login2x()
    closeAll()
    for i = 1, 8 do TK.Machine:RememberAccount("account" .. i) end
    TK.Login.account = nil
    TK.Login:LogOut()
    TK.Login:Submit()   -- no password: the error line shows
end

function states.settings2x()
    closeAll()
    TK.Machine:SetUIScale(2)
    TK.Settings:Open("bar1", "General Settings")
end

function states.bag()
    closeAll()
    V.Toggle("bag")
    TK.UI.OpenMenu(TK.Game.Inventory.Commands(1), TKBagSlot1) -- by Modern's bag's slot a, when it is the bag shown
end

function states.spellbook()
    closeAll()
    V.Open("spellbook", "input")
end

-- Round 18: a spell's tooltip with its cost, and its cost on the mana bar (the mock world's costs).
function states.manapreview()
    closeAll()
    V.Open("spellbook", "input")
    local cell = TKSpellBookSlot2 -- Modern's spell book's; not there when another interface draws the spells
    if not cell then return end
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    GameTooltip:AddLine(select(2, __tk:GetSpellSlot(2)), 1, 1, 1)
    TK.AddSpellCostLine(select(2, __tk:GetSpellSlot(2)))
    GameTooltip:Show()
    TK.ManaPreview.Show(select(2, __tk:GetSpellSlot(2)))
end

function states.keybindings()
    TK.ManaPreview.Hide()
    GameTooltip:Hide()
    closeAll()
    TK.Settings:Open("keybindings", "General")
end

function states.social()
    closeAll()
    V.Open("group", "input")
    V.Toggle("emotes")
end

function states.classic()
    closeAll()
    TK.Settings:SetOption("classic", "enabled", true)
    TK.Bindings.commands["CLASSICEAT"].fn()   -- e: the Eat prompt
end

function states.newchar()
    TK.Settings:SetOption("classic", "enabled", false)
    closeAll()
    TK.Login.account = "aria"
    TK.Login:LogOut()
    TK.Login.connected = true
    TK.Login:ShowCreate()
end

function states.servers()
    closeAll()
    TK.Login:LogOut()
    TK.Login.Servers()
    __tk:AddServer("Home server", "192.168.222.232", 3000)
    TK.Settings:Open("servers")
end

function __tk_preview(state)
    local fn = states[state]
    if fn then TK.SafeCall(fn) else __tk:LogError("unknown preview state " .. tostring(state)) end
end
