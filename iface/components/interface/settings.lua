local C = TK.GetComponent("interface")

-- Listed on the login screen's settings too, under General (the settings list's tab for interface-wide settings).
C.atLogin = true
C.category = "general"

-- s6-devtools (round 3; the owner, 2026-10-05): Show Frame Time moved to the Debug page (components/debug), which carries
-- a profile's choice over.
C.defaults = {
    animateSpellIcons = false,
    -- s6-ui-core (round 53; the owner, 2026-10-05: "about 25% for all Modern panels"): the UI transparency (core/widgets.lua)
    uiTransparency = TK.UI.defaultTransparency, -- s6-ui-core (round 56): one default for all
}

--- s6-ui-core (round 53): a profile from before the UI Transparency had Panel Transparency (on or off) and its percent,
--- 60 by default. Off is 0; a percent the player chose is kept; the old default becomes the new 25. (A profile saves
--- every value, so a chosen 60 cannot be told from the default: it becomes 25 too.)
function C:Migrate(saved)
    if saved.uiTransparency ~= nil or (saved.panelTransparency == nil and saved.panelTransparencyPercent == nil) then
        return false
    end
    local percent = saved.panelTransparencyPercent
    if saved.panelTransparency == false then
        saved.uiTransparency = 0
    elseif type(percent) == "number" and percent ~= 60 then
        saved.uiTransparency = percent
    end
    saved.panelTransparency, saved.panelTransparencyPercent = nil, nil
    return true
end

--- The profile's looks (Dialogs and Cursors, the Looks tab below), and what a first start in the active interface gives.
local function looks() return TK.DB.profile.looks end
local function firstLook(kind)
    return function() return TK.DB:InFirstProfile(function() return (looks() or {})[kind] end) end
end

C.tabs = {
    { name = "General Settings", args = {
        { type = "header", name = "Scale" },
        { type = "range", name = "UI Scale", min = 0.5, max = 2, step = 0.05, machine = true,
          get = function() return TK.Machine:EffectiveUIScale() end,
          set = function(_, v)
              TK.Machine:SetUIScale(v)
          end,
          default = function() return TK.Machine.defaults.uiScale end }, -- s6-ui-settings: the page's reset
        { type = "toggle", name = "Fit to Screen", machine = true,
          get = function() return TK.Machine:Get().uiScaleAuto end,
          set = function(_, on) TK.Machine:SetUIScaleAuto(on) end,
          default = function() return TK.Machine.defaults.uiScaleAuto end },
        { type = "description", name = "The whole interface is drawn at the window's own resolution; the UI scale enlarges or shrinks every frame at once. Each frame's own Scale multiplies it. Fit to Screen chooses the scale from the screen's height (1.0 at 1080 pixels) until one is set by hand. Kept for this computer, not in the profile." },
        { type = "header", name = "Login Screen" },
        { type = "toggle", name = "Show Saved Accounts", machine = true,
          get = function() return TK.Machine:Get().showRecent end,
          set = function(_, on)
              TK.Machine:Get().showRecent = on
              if TK.Login:IsShown() then TK.Login:RefreshSaved() end
          end,
          default = function() return TK.Machine.defaults.showRecent end },
        { type = "description", name = "The login screen lists the accounts saved for the server (with Save account information). Their passwords are encrypted for this Windows user." },
        -- s6-ui-login (round 10; the owner, 2026-10-05): the login screen's scene held still (core/login.lua)
        { type = "toggle", name = "Disable Login Page Animations", machine = true,
          get = function() return TK.Machine:Get().disableLoginAnimations end,
          set = function(_, on)
              TK.Machine:Get().disableLoginAnimations = on
              __tk:SetLoginSceneStill(on)
          end,
          default = function() return TK.Machine.defaults.disableLoginAnimations end,
          -- s6-ui-login (round 11; the head's review: player text is short): the line says what it does, the tooltip the rest.
          -- s6-ui-core (round 52; the owner's rule, 2026-10-05: label and value on the page): the line is the tooltip's too.
          desc = "Holds the login background still at night: no day and night, drifting mountains and clouds or twinkling stars. Off, the scene follows a ten-minute day from the computer's clock. Kept for this computer." },
        { type = "header", name = "Panels" },
        -- s6-ui-core (round 53; the owner, 2026-10-05): one transparency for every panel and window
        { type = "range", key = "uiTransparency", name = "UI Transparency (%)", min = 0, max = 100, step = 5,
          desc = "How much the map shows through every panel and window. A panel can have its own in its settings." },
        { type = "header", name = "Spell Icons" },
        { type = "toggle", key = "animateSpellIcons", name = "Animate Spell Icons" },
        { type = "description", name = "A spell's icon is a frame of its effect, learned from your own casts on this server. With this on, the spell book and the action bars play the effect's animation." },
        { type = "header", name = "Lua" },
        { type = "execute", name = "Reload UI", func = function() ReloadUI() end },
        { type = "description", name = "Reloads every component from the lua folder on disk, keeping the profile. Ctrl+Shift+R does the same at any time." },
    } },
    -- s6-ui-core (round 83; the owner, 2026-10-09: "If it makes sense move it for now and I'll decide later"; research
    -- 2026-10-09-interface-graphics-options.md: they change the interface's look, not the game world's): Dialogs and Cursors,
    -- moved here from Graphics' Asset Styles (round 54 had moved them there from the Interfaces page), the profile's looks
    -- as before (TK.DB.profile.looks). Nothing is sent when they change. s6-interface-5x (round 12, merge of main): each
    -- resets to what a first start in the active interface gives (TK.DB:InFirstProfile; round 11's W12,
    -- interface-separation.md 5.17): 7.x's and 5.x's own dialogs, 5.x's cursors.
    { name = "Looks", args = {
        { type = "select", name = "Dialogs", values = function() return TK.Interfaces:DialogLooks() end,
          default = firstLook("dialogs"),
          get = function() return looks().dialogs end,
          set = function(_, v)
              looks().dialogs = v
              TK.DB:MarkDirty()
              TK.GetComponent("dialogs"):ApplySettings()
          end },
        { type = "select", name = "Cursors", default = firstLook("cursors"),
          values = function() return TK.Interfaces:CursorLooks() end, -- s6-interface-5x-b: the original's, and the interfaces' sets
          get = function() return looks().cursors end,
          set = function(_, v)
              looks().cursors = v
              TK.DB:MarkDirty()
              TK.Cursor:ApplySet()
          end },
    } },
}
