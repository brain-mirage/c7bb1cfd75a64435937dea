-- s6-interface-5x-b (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md): 5.33's options window,
-- OptionPane (constructor 0x00487BD0, F10: UserPane_HandleKeyOrTextEvent 0x004D5090), the look of 5.x's options. While
-- this panel is on, the game layer's opener (F10, TK.Game.Options.Toggle, core/game/options.lua) shows it in place of
-- Modern's window (s6-play-modes round 8, interface-separation step 4: by TK.Game.Options.ProvideWindow).
--
-- 5.33's window: DLGOPT.EPF in NPAL8.PAL (407 x 410), at its placement slot 3 (centred on (320, 240) by 5.33's defaults);
-- twelve radio groups (controls 2-13) at (227, 80 + 14 i)-(311, 91 + 14 i), each ON at (0, 0)-(33, 11) and OFF at (56, 0)-
-- (94, 11) of its group, drawn by RadioGroupControlPane's paint (sub_419DA0: RADIOBUT.EPF in NPAL8.PAL, frame 1 for the
-- chosen option and 0 for the other, at the option's left on its middle row); the image buttons SPELL MACRO (54), SAY
-- MACRO (55), FRIENDS (56) and PROFILE (57) at (120, 258 + 19 i)-(289, 276 + 19 i) and OK (14) at (168, 360)-(240, 376).
-- The rows' captions are the picture's: MUSIC, SOUND EFFECT, MAGIC EFFECT, WEATHER CHANGE, ACTION ICONS, WISDOM, FAST
-- MOVE, DOUBLE CLICK, SHADOW & LIGHTING, SEE THROUGH EFFECT, SAY WITH ENTER KEY, HEAR EMOTIONS.
--
-- What it sends: 5.x is a look over 7.5.2. 5.33's window asks the server for the options on opening (1B 00) and sends
-- its own two-byte 1B for a server option's change (OptionPane_OnControlCommand 0x004880F0); 7.5.2's options tab
-- (NewOptionPane) asks nothing on opening and turns an option over with a press on its row. So opening this sends
-- nothing, and a press on the option that is not chosen does what the press on 7.5.2's row for the same option does,
-- through the same action as Modern's Game Options window (TK.Actions' optionrow, frozen at the left press and run by
-- the rules: NewOptionPane::HandlePointerOrMouseEvent 0x00540910); a press on the chosen one does nothing. Wire, by row:
--   SOUND EFFECT  row 17: 1B 01 63 0D v      MAGIC EFFECT  row 3: 1B 01 05      WEATHER CHANGE  row 4: 1B 01 06
--   WISDOM        row 10: 1B 01 04 (Advice)   DOUBLE CLICK  row 14 (local)      SHADOW & LIGHTING  row 18 (local)
--   FAST MOVE     nothing: 7.5.2 turns option 9 (1B 01 09) only from its F12 key (KeyCommandRules: a key's input only;
--                 its tab has no row for it), so here it shows the server's state and a press on it sends nothing.
-- Each row shows what 7.5.2's tab shows for it (NewOptionPane::OnPaint 0x00540600), whichever way it changed. The
-- server's options are shown as the session keeps them (the rules' Session.ServerOptions: the server's answers, and
-- F12's flip of option 9). SOUND EFFECT is Config's m_soundEffectsEnabled, the server's option (row 17), which F7 leaves
-- alone (UserPane.cpp:1714-1722 turns the effects' playback only): after F7 it still shows the server's state, and its
-- press is row 17's whatever F7 did (OptionPane.cpp:1044 sends 1B 01 63 0D !option, with no local exception). MUSIC is
-- Config's music flag (row 16, field_28DE50), which F7 clears and sets too (MuteMusic and UnmuteMusic go through
-- MidiPlayer::Disable and Enable, MidiPlayer.cpp:256-270); its press is row 16's, local (the flag, then
-- ApplyEffectAndMusicOptions 0x00541120: the music muted or back, the volume kept; nothing sent). The other local
-- switches 7.5.2's tab has no row for are the client's own settings: ACTION ICONS 5.x's icon row (all eight or Help and
-- Quit), SEE THROUGH EFFECT the world view's see-through, SAY WITH ENTER KEY the chat's Use Enter to Talk, HEAR EMOTIONS
-- Config's HearEmotions. Changing an option's action, which press runs it, or what a row shows (so which option is
-- "not chosen"), changes what the server sees.
-- The buttons: FRIENDS and PROFILE run what 7.5.2 runs for them (F3's friend list, the Menu's Profile: the dialog
-- model's FriendListDialog and ProfileDialog; nothing sent on opening); SPELL MACRO opens 7.5.2's Macro Setup (the
-- model's IntegrateMacroDialog, the macro window's Hotkeys tab) where the player's setting offers it, else the macro
-- window; SAY MACRO the macro window (7.5.2 has no say macros) (decision 2026-10-04-5x-options-and-macro-windows); OK closes.

local C = TK.GetComponent("5x.options")
local H = __tk
local S = require("interfaces.5x.skin")
local Screen = require("interfaces.screen")

local WIDTH, HEIGHT = 407, 410

-- s6-play-modes (round 8, step 4): the game layer's options and sound (core/game/options.lua, core/game/sound.lua)
local O, Sound = TK.Game.Options, TK.Game.Sound

--- The server's option by its name in the game layer's state (1 on), or nil offline.
local function server(name)
    local state = O.ServerState()
    return state and state[name] == 1
end

-- The rows, top to bottom (5.33's controls 2-13): on() the state 7.5.2's tab shows, row = 7.5.2's option row
-- (optionrow), set(on) a local switch; a row with neither (FAST MOVE) only shows its state.
-- Wire: SOUND EFFECT shows the server's option (NewOptionPane::OnPaint row 17: Config's m_soundEffectsEnabled), not the
-- effects F7 turned, so its press sends row 17's 1B 01 63 0D v after F7 as 7.5.2's does (OptionPane.cpp:1044).
C.rows = {
    { name = "MUSIC", on = function() return Sound.MusicOn() == true end,
      set = function(on) Sound.SetMusicOn(on) end },
    { name = "SOUND EFFECT", row = 17, on = function() return server("sound") end },
    { name = "MAGIC EFFECT", row = 3, on = function() return server("magic") end },
    { name = "WEATHER CHANGE", row = 4, on = function() return server("weather") end },
    -- s6-interface-5x (round 13, the separation's step 11): the icons' code only while they are loaded (on)
    { name = "ACTION ICONS",
      on = function() local i = TK.GetComponent("5x.icons") return i == nil or not i:Loaded() or i:ShowsAll() end,
      set = function(on) local i = TK.GetComponent("5x.icons") if i and i:Loaded() then i:SetAll(on) end end },
    { name = "WISDOM", row = 10, on = function() return server("advice") end },
    { name = "FAST MOVE", on = function() return server("movement") end },
    { name = "DOUBLE CLICK", row = 14, on = function() return O.Get("double_click") end },
    { name = "SHADOW & LIGHTING", row = 18, on = function() return O.Shadows() end },
    -- s6-input (round 49, separation step 4b): the shared world view's own setting, through TK.WorldView:Set
    { name = "SEE THROUGH EFFECT", on = function() return TK.WorldView ~= nil and TK.WorldView:DB().seeThrough ~= false end,
      set = function(on) if TK.WorldView then TK.WorldView:Set("seeThrough", on) end end },
    { name = "SAY WITH ENTER KEY", on = function() return O.Get("say_with_enter") end,
      set = function(on) O.Set("say_with_enter", on) H:ApplyChat() end },
    { name = "HEAR EMOTIONS", on = function() return O.Get("hear_emotions") end,
      set = function(on) O.Set("hear_emotions", on) end },
}

-- The buttons: image, the action 7.5.2 runs for it (frozen at the press, run on the release) or a local opener. Wire:
-- FRIENDS is 7.5.2's F3 (UserPane::HandleKeyOrTextEvent 0x005A5BD0: new FriendListDialog, 0x0053F2C0), PROFILE the
-- Menu popup's Profile (MenuVarietySelectPane: new ProfileDialog, 0x0053F940), SPELL MACRO its Macro Setup
-- (IntegrateMacroDialog 0x00541B30); none sends anything on opening, and what their windows send is the model's.
local BUTTONS = {
    { id = 54, name = "SpellMacro", run = function()
          local macros = TK.GetComponent("macros")
          if macros and macros:OriginalSetup() then TK.Actions:RunFrozen() elseif macros then macros:Open() end
      end, action = { kind = "dialog:open", text = "IntegrateMacroDialog" } },
    { id = 55, name = "SayMacro", run = function() local m = TK.GetComponent("macros") if m then m:Open() end end },
    { id = 56, name = "Friends", action = { kind = "dialog:open", text = "FriendListDialog" } },
    { id = 57, name = "Profile", action = { kind = "dialog:open", text = "ProfileDialog" } },
}

--- A row's switch for one of its options (ON, or OFF) at (l, t)-(r, b) of the window: the radio picture and the press.
local function option(win, r, isOn, l, t, rgt, b)
    local f = CreateFrame("Button", nil, win)
    f:SetPoint("TOPLEFT", win, "TOPLEFT", l, -t)
    f:SetSize(rgt - l, b - t)
    f:RegisterForClicks("LeftButtonUp")
    f.pic = f:CreateTexture(nil, "ARTWORK")
    f.pic:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(math.floor((b - t) / 2) - 5))
    f.isOn = isOn
    -- Wire: a press on the option that is not chosen is the 7.5.2 row's press (its action frozen at this press, the rules
    -- send it: NewOptionPane::HandlePointerOrMouseEvent 0x00540910); local switches change here and send nothing.
    -- C:Refresh sets the action only on the option that would change the state.
    f:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or r.on() == isOn then return end
        if r.row then
            O.Press(r.row)
        elseif r.set then
            r.set(isOn)
        end
        C:Refresh()
    end)
    return f
end

local function build()
    local win = CreateFrame("Frame", "TK5xOptions", UIParent)
    C:Own(win) -- the component's root (Astra's review of round 1): a replaced component keeps it hidden (TK.ReplaceComponent)
    -- HIGH, the macro window's strata, so SAY MACRO and SPELL MACRO show it over this window (round 93, as the XML form)
    win:SetFrameStrata("HIGH")
    win:SetSize(WIDTH, HEIGHT)
    win:EnableMouse(true)
    win.back = S.Picture(win, nil, "DLGOPT.EPF", 0, "NPAL8.PAL", 0, 0, "BACKGROUND")
    -- without the 5.33 set, a plain panel so the window stays usable
    if not S.Image("DLGOPT.EPF", 0, "NPAL8.PAL") then
        S.Fill(win:CreateTexture(nil, "BACKGROUND"), S.TEXT, 0.85):SetAllPoints(win)
    end
    win.rows = {}
    for i, r in ipairs(C.rows) do
        local t = 80 + 14 * (i - 1)
        local row = { on = option(win, r, true, 227, t, 260, t + 11), off = option(win, r, false, 283, t, 321, t + 11) }
        if not S.Image("DLGOPT.EPF", 0, "NPAL8.PAL") then
            local caption = S.Text(win:CreateFontString(nil, "OVERLAY"), S.WHITE)
            caption:SetPoint("TOPLEFT", win, "TOPLEFT", 84, -(t + 1))
            caption:SetText(r.name)
        end
        win.rows[i] = row
    end
    local X = require("interfaces.5x.dialogs").X
    win.x5 = true -- X.Image's focus mark asks the window
    win.buttons = {}
    for i, def in ipairs(BUTTONS) do
        local b = CreateFrame("Button", "TK5xOptions" .. def.name, win)
        b:RegisterForClicks("LeftButtonUp")
        X.Image(win, b, def.id, 120, 258 + 19 * (i - 1), 289, 276 + 19 * (i - 1))
        if def.action then TK.Actions:SetTable(b, def.action) end
        b:SetScript("OnClick", function()
            if def.run then def.run() else TK.Actions:RunFrozen() end
        end)
        win.buttons[i] = b
    end
    win.ok = CreateFrame("Button", "TK5xOptionsOK", win)
    win.ok:RegisterForClicks("LeftButtonUp")
    win.ok.x5focus = true -- OK has the focus (SetFocusedControl(1)): X.Image's 1-pixel frame in 0x80 round it
    X.Image(win, win.ok, 14, 168, 360, 240, 376)
    win.ok:SetScript("OnClick", function() win:Hide() end)
    -- the server's answers (0x23, 0x08) change its options' state: an open window looks a few times a second
    win:SetScript("OnUpdate", TK.Util.Throttled(0.2, function() C:Refresh() end))
    -- s6-rules-dialogs' hook, as Modern's window: while the options show, the server's "saved" (S 0x21) is its alert
    win:HookScript("OnShow", function() H:DialogOptionPageShown(true) C:Refresh() end)
    win:HookScript("OnHide", function() H:DialogOptionPageShown(false) end)
    TK.Escape:AddWindow(win, function() win:Hide() end) -- Escape closes it, as Modern's window
    win:Hide()
    C.window = win
    return win
end

--- The radio pictures by the states now, and each option's action: a server row's on the option that would turn it over.
function C:Refresh()
    local win = self.window
    if not win or not win:IsShown() then return end
    for i, r in ipairs(self.rows) do
        local state = r.on() and true or false
        for _, f in ipairs({ win.rows[i].on, win.rows[i].off }) do
            local chosen = f.isOn == state
            local key, w, h = S.Image("RADIOBUT.EPF", chosen and 1 or 0, "NPAL8.PAL")
            if key then
                -- the frame at the option's left, its top on the option's middle row - 5 (its drawn pixels from their place)
                local ox, oy = TK.Art.Origin(key)
                f.pic:SetTexture(key)
                f.pic:SetSize(w, h)
                f.pic:ClearAllPoints()
                f.pic:SetPoint("TOPLEFT", f, "TOPLEFT", ox, -(math.floor(f:GetHeight() / 2) - 5 + oy))
                f.pic:Show()
            else
                f.pic:SetColorTexture(1, 1, 1, chosen and 1 or 0.3)
                f.pic:SetSize(11, 11)
            end
            if r.row and not chosen then TK.Actions:Set(f, "optionrow", nil, r.row) else TK.Actions:Clear(f) end
        end
    end
end

--- At slot 3's place: centred on the 640 x 480 screen, at its scale.
function C:Place()
    local win = self.window
    local s, left, top = Screen.Fit(S.WIDTH, S.HEIGHT)
    win:SetScale(s)
    local x, y = S.WIDTH / 2 - math.floor(WIDTH / 2), S.HEIGHT / 2 - math.floor(HEIGHT / 2)
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (left + x * s) / s, -(top + y * s) / s)
end

--- The Game Options' opener while this panel is on: shows or hides 5.33's window (true: taken).
function C:Toggle()
    if not (self:DB().enabled == true and TK.GameState:InWorld()) then return false end
    local win = self.window or build()
    if win:IsShown() then
        win:Hide()
    else
        self:Place()
        win:Show()
        Sound.PlayEffect(0x198) -- DialogPane::AddToLayer's open sound, 5.x's dialogs' (sound only)
    end
    return true
end

function C:IsOpen() return self.window ~= nil and self.window:IsShown() end

-- The game layer's opener asks this window first while the panel is on (C:Toggle is false while it is off).
O.ProvideWindow("5x.options", function() return C:Toggle() end)

function C:ApplySettings()
    if self.window and (self:DB().enabled ~= true or not TK.GameState:InWorld()) then self.window:Hide() end
    if self:IsOpen() then self:Place() end
end

Screen.Follow(C, "ApplySettings")
