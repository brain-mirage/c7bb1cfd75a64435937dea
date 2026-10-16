-- s6-interface-7x-b (round 5; the owner, 2026-10-05: "The 7x theme is supposed to match the functionality of the
-- original"): 7.x's options tab (side panel tab 6), 7.5.2's own options page, 4a's NewOptionPane (ui/OptionPane.cpp,
-- constructor 0x0053FF90), drawn in the side panel's pane in place of Modern's Game Options window, whose rows' actions it
-- runs (s6-play-modes round 8, interface-separation step 4: through the game layer's TK.Game.Options, core/game/options.lua).
--
-- Drawing (OnPaint 0x00540600, BuildOptionRows 0x00541240, DrawOptionButtonItem 0x005416D0): OPTION.EPF frame 0 in
-- OPTION.PAL; two pages (field_12B8 = 2); page 0's headings "Show Effects" (2, 64), "Listen to" (2, 154), "Semi-trans"
-- (2, 208) and "System" (2, 226) in 0x80, twice a pixel apart; each row a box (ONOFFBUT.EPF 0 off, 1 on, in BUTTON.PAL) or
-- a radio (RBUTTON.EPF 1 off, 0 on, in RBUTTON.PAL) at its rectangle's corner, its label in colour 6 at (l + 19, t + 13)
-- then in 0x80 at (l + 18, t + 13); the rectangle (x, y)-(x + w(label) + 18, y + 18), the label part of the press
-- (InitOptionRow 0x005411B0); the page arrows (rows 0 and 1) at (147, 269) and (166, 269), INVENBUT.EPF 5 / 12 / 19 and
-- 6 / 13 / 20 (normal, pressed after its own step until the next paint, greyed at the first or last page); the Music and
-- Sound volume sliders on page 0 (UpdateRenderRegion 0x005402A0: ScrollVolumePane, 82 x 13 at the row's top right +
-- (20, 1), SCRBUTT2.EPF's 38-pixel thumb, over CScrollBarBackPane's groove, 120 x 5 at + (10, 5)).
--
-- What a press does, by 4a's row (NewOptionPane::HandlePointerOrMouseEvent 0x00540910, ui/OptionPane.cpp:986-1082; a
-- single left press only, event type 1: a double click's second press and the releases do nothing):
--   WIRE   3 Magic 1B 01 05 (and Manual); 4 Weather 1B 01 06; 10 Advice 1B 01 04 (SendOpcode1BSubcode01Packet 0x00540E50,
--          three bytes); 7 Fixed movement 1B 01 07 00; 11 Shout 1B 01 03 00; 12 Whisper 1B 01 01 00 (UserPane's sender);
--          17 Sound 1B 01 63 0D v, v the server's state turned over (SendOptionPacket11B63 0x00540EA0); 20 Low and
--          21 High: the map effects, shadows and balloon fill to the mode, then 1B 01/02 05 06 for the effects that
--          differ from it, or nothing (SendLowHighDisplayModeOption 0x00541040)
--   local  2 Map, 18 Shadow, 19 Chat (balloon fill), each also the radio to Manual; 22 Manual; 14 Simple Click; 13 Snore
--          and its line; 23 Orb / spell target share; 24 the F1 / Shift+F1 swap
--   these 17 rows run Modern's window's action for the same row (TK.Actions' optionrow with the row number, frozen at
--   the press, run by the rules after the dispatcher's gates: TK-Core OptionRules.Row, through s6-rules-items' option
--   sender for the packets; offline the game layer's LocalRow), so a press here sends exactly what a press on Modern's
--   row sends, at the same moment. Changing a row's number, which press runs it, or the action sends something else.
--   local, here 5 Display names, 8 BLDG (the object transparency), 9 Use enter to talk, 16 Music, 25 Group HP/MP bars,
--          26 Names in carnage dye: Config flags (the rules leave these rows alone: OptionRules.Row's default), the
--          owning components' switches here; nothing sent. Round 7: 5, 25 and 26 are Config's own flags in settings.toml
--          (ShowUserName, GroupBar, CarnageColor: OptionPane.cpp:1007-1009, 1072-1081), 5 and 26 handed at once to the
--          world view's names (LocalOptions), which 7.x shows (the nameplates component is off in 7.x); 25 is stored
--          only, as 7.x draws no group members' bars on the map yet (the job's notes)
--   The server's rows show the server's state (Session.ServerOptions from 0x23 and 0x08, as 4a draws Config's) and change
--   only when it answers: the page looks a few times a second while it shows.
-- The arrows, Page Up and Page Down (HandleKeyOrTextEvent 0x00540880, MoveSelection 0x00541A20) turn the pages, and each
-- accepted switch to the tab shows page 0 (AddToLayer 0x005404D0); the sliders set the music and effects volumes (20
-- steps, NewOptionPane::ApplyVolumeChange 0x00540490). None of these send anything. A press on a slider takes the input's
-- capture until its release, as its ScrollPane kind captures the mouse (ScrollPane.cpp:125): WIRE, a game key pressed
-- while the slider is held reaches nothing (m sends no 7C); changing it changes what the server sees.

local H = __tk
local S = require("interfaces.7x.skin")
local K = require("interfaces.7x.panels.side.kit")

local O = {}

-- s6-play-modes (round 8, step 4): the game layer's options and sound (core/game/options.lua, core/game/sound.lua)
local GameOptions, Sound = TK.Game.Options, TK.Game.Sound

--- The server's option by its name in the game layer's state (1 on); off without a session.
local function server(name)
    local state = GameOptions.ServerState()
    return state ~= nil and state[name] == 1
end

--- A component's switch (its settings page's key), set as its page (page: the node's id) sets it.
local function db(component, key)
    local c = TK.GetComponent(component)
    return c ~= nil and c:DB()[key] == true
end
local function setDb(page, key, on) TK.Settings:SetOption(page, key, on) end

-- The rows (BuildOptionRows: row, label, the rectangle's corner, kind 3 box / 4 radio, page), each with what it shows
-- (OnPaint's switch, OptionPane.cpp:879-953) and, for the rows the rules leave alone, its local switch. A row with
-- send = true runs the optionrow action (above).
local ROWS = {
    { 14, "Simple Click", 8, 16, 3, 0, on = function() return not GameOptions.Get("double_click") end, send = true },
    { 9, "Use enter to talk", 8, 34, 3, 0, on = function() return GameOptions.Get("say_with_enter") end,
      set = function(on) GameOptions.Set("say_with_enter", on) H:ApplyChat() end },
    { 2, "Map", 8, 70, 3, 0, on = function() return GameOptions.MapEffects() end, send = true },
    { 3, "Magic", 88, 70, 3, 0, on = function() return server("magic") end, send = true },
    { 4, "Weather", 8, 88, 3, 0, on = function() return server("weather") end, send = true },
    { 18, "Shadow", 88, 88, 3, 0, on = function() return GameOptions.Shadows() end, send = true },
    -- s6-play-modes (round 8, W6): Config's m_showUserName, the one global Display names the drawing follows
    { 5, "Display names", 8, 106, 3, 0, on = function() return GameOptions.ShowNames() end,
      set = function(on) GameOptions.SetShowNames(on) end },
    { 7, "Fixed movement", 8, 124, 3, 0, on = function() return server("fixed") end, send = true },
    { 10, "Advice", 8, 160, 3, 0, on = function() return server("advice") end, send = true },
    { 12, "Whisper", 88, 160, 3, 0, on = function() return server("whispers") end, send = true },
    { 11, "Shout", 8, 178, 3, 0, on = function() return server("shouts") end, send = true },
    { 13, "Snore", 88, 178, 3, 0, on = function() return H:ClientSettingInt("options", "hear_snore") ~= 0 end, send = true },
    { 8, "BLDG", 71, 196, 3, 0, on = function() return db("worldview", "objectTransparency") end,
      set = function(on) setDb("worldviewgraphics", "objectTransparency", on) end }, -- s6-ui-core (round 83): Graphics' World View
    { 19, "Chat", 131, 196, 3, 0, on = function() return GameOptions.Get("balloon") end, send = true },
    { 20, "Low", 42, 214, 4, 0, on = function() return GameOptions.System() == 0 end, send = true },
    { 21, "High", 84, 214, 4, 0, on = function() return GameOptions.System() == 1 end, send = true },
    { 22, "Manual", 130, 214, 4, 0, on = function() return GameOptions.System() == 2 end, send = true },
    { 16, "Music", 8, 232, 3, 0, on = function() return Sound.MusicOn() == true end,
      set = function(on) Sound.SetMusicOn(on) end },
    { 17, "Sound", 8, 250, 3, 0, on = function() return server("sound") end, send = true },
    { 23, "Orb/Spell target share", 8, 16, 3, 1, on = function() return GameOptions.Get("orb_target_share") end, send = true },
    { 24, "F1/Shift+F1 swap", 8, 34, 3, 1, on = function() return GameOptions.Get("f1_swap") end, send = true },
    { 25, "Show group HP/MP bars", 8, 52, 3, 1, on = function() return GameOptions.Get("group_bar") end,
      set = function(on) GameOptions.Set("group_bar", on) end },
    { 26, "Show names in carnage dye", 8, 70, 3, 1, on = function() return GameOptions.Get("carnage_color") end,
      set = function(on) GameOptions.Set("carnage_color", on) end },
}

local HEADINGS = { { "Show Effects", 64 }, { "Listen to", 154 }, { "Semi-trans", 208 }, { "System", 226 } }

local PAGES = 2

-- ----- the volume sliders (ScrollVolumePane, ui/ScrollPane.cpp) -----

local TRAVEL = 82 - 38 -- the thumb's left ranges over the slider's width less its 38 pixels (GetPartRect)

local function audio() return TK.GetComponent("audio") end

--- The volume's step 0..20 (the stored volume / 5: RefreshVolumeDisplay 0x00540FF0); the Sound settings keep 0..1. 4a
--- shows the stored volume whatever the Music flag (round 7); the Sound settings' music is 0 while the flag is off, so
--- the music's step is the audio logic's playback volume.
local function volume(key)
    local a = audio()
    if not a then return 0 end
    local v = key == "music" and Sound.MusicVolume() or a:Sound()[key] -- s6-play-modes (round 9): the sound layer's
    return math.max(0, math.min(20, math.floor((v or 0) * 20 + 0.5)))
end

--- ApplyVolumeChange: the new step kept and applied. Round 7: the music's volume alone, 0 included (4a sets the volume
--- to 0 and leaves the Music flag: TK.Game.Sound.SetMusicVolume), where the Sound page turns the music off at 0.
local function setVolume(key, step)
    local a = audio()
    if not a then return end
    if key == "music" then
        TK.SafeCall(Sound.SetMusicVolume, step / 20) -- s6-play-modes (round 9): the sound layer's (TK.Game.Sound)
    else
        a:Sound()[key] = step / 20
        TK.SafeCall(a.ApplySettings, a, key, step / 20)
    end
    TK.Machine:MarkDirty()
end

--- A slider for key ("music" row 16, "effects" row 17) right of the row's rectangle r.
local function slider(p, key, r)
    local l, t = r[3] + 20, r[2] + 1
    local s = K.Hit(p, l, t, l + 82, t + 13)
    -- WIRE: a press here captures the input until its release (ScrollPane's kind: ScrollPane.cpp:125); see the header
    s:SetCapturesPress(true)
    s:SetPassesDoubles(true)
    s.key = key
    -- the groove (CScrollBarBackPane::OnPaint 0x0053FF00): three lines x 7-94 at y 1-3, a stub each side at y 2 (x 0-4,
    -- x 98-102) and the right one's stroke x 100 at y 0-4, in the draw colour, at (row's right + 10, row's top + 5)
    local gl, gt = r[3] + 10, r[2] + 5
    s.groove = {}
    for i, g in ipairs({ { 7, 1, 88, 3 }, { 0, 2, 5, 1 }, { 98, 2, 5, 1 }, { 100, 0, 1, 5 } }) do
        local tex = S.Fill(p:CreateTexture(nil, "BORDER"), S.TEXT)
        tex:SetPoint("TOPLEFT", p, "TOPLEFT", gl + g[1], -(gt + g[2]))
        tex:SetSize(g[3], g[4])
        s.groove[i] = tex
    end
    function s:Draw()
        local left = self.dragging and self.dragLeft or math.floor(TRAVEL * volume(self.key) / 20)
        self.thumb = S.Picture(p, self.thumb, "SCRBUTT2.EPF", self.dragging and 1 or 0, "BUTTON.PAL", l + left, t, "ARTWORK")
    end
    -- NotifyValueChange: the thumb's left from the pointer less where it was taken (plus one), kept in the travel, as a
    -- step (x * 21 / travel, at most 20); a press on the page areas takes the thumb by its middle
    local function follow()
        local x = math.floor((K.PointIn(s)))
        s.dragLeft = math.max(0, math.min(TRAVEL, x - s.grab + 1))
        local step = math.min(20, math.floor(s.dragLeft * 21 / TRAVEL))
        if step ~= volume(s.key) then setVolume(s.key, step) end
        s:Draw()
    end
    s:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local x = K.PointIn(s)
        local left = math.floor(TRAVEL * volume(s.key) / 20)
        s.grab = (x >= left and x < left + 38) and math.floor(x - left) or 19
        s.dragging = true
        follow()
        s:SetScript("OnUpdate", follow)
    end)
    s:SetScript("OnMouseUp", function()
        s.dragging = false
        s:SetScript("OnUpdate", nil)
        s:Draw()
    end)
    function s:SetShownAll(on)
        self:SetShown(on)
        for _, g in ipairs(self.groove) do g:SetShown(on) end
        if self.thumb then self.thumb:SetShown(on) end
    end
    return s
end

-- ----- the page -----

function O.Build(parent)
    local p = CreateFrame("Frame", "TK7xSideOptions", parent)
    p:SetAllPoints(parent)
    p.page = 0
    p.back = S.Picture(p, nil, "OPTION.EPF", 0, "OPTION.PAL", 0, 0, "BACKGROUND")
    p.headings = {}
    for i = 1, #HEADINGS do p.headings[i] = { K.Text(p), K.Text(p) } end
    p.rows = {}
    for _, def in ipairs(ROWS) do
        local label = def[2]
        local x, y = def[3], def[4]
        local w = S.TextWidth(label) or 0
        local r = { x, y, x + w + 18, y + 18 }
        local b = K.Hit(p, r[1], r[2], r[3], r[4], "TK7xOption" .. def[1])
        b.def, b.rect = def, r
        b.box = b:CreateTexture(nil, "ARTWORK")
        b.shadow, b.label = K.Text(p), K.Text(p)
        if def.send then
            -- WIRE: Modern's window's row action, run by the rules (the header); the press, not the release
            TK.Actions:Set(b, "optionrow", nil, def[1])
            b:SetScript("OnMouseDown", function(_, button, double)
                if button ~= "LeftButton" or double then return end
                GameOptions.Press(def[1])
                O.Show(p)
            end)
        else
            b:SetScript("OnMouseDown", function(_, button, double)
                if button ~= "LeftButton" or double then return end
                def.set(not def.on())
                O.Show(p)
            end)
        end
        p.rows[#p.rows + 1] = b
        if def[1] == 16 then p.music = slider(p, "music", r) end
        if def[1] == 17 then p.effects = slider(p, "effects", r) end
    end
    -- the arrows: rows 0 and 1 (InitOptionRow with an empty label: 18 x 18), their press MoveSelection
    p.back1 = K.Hit(p, 147, 269, 165, 287, "TK7xOptionBack")
    p.on1 = K.Hit(p, 166, 269, 184, 287, "TK7xOptionOn")
    p.back1:SetScript("OnMouseDown", function(_, button, double)
        if button == "LeftButton" and not double then O.Page(p, -1) end
    end)
    p.on1:SetScript("OnMouseDown", function(_, button, double)
        if button == "LeftButton" and not double then O.Page(p, 1) end
    end)
    -- the server's answers (0x23, 0x08) change its rows: the page looks a few times a second while it shows
    -- (s6-reprojection round 56, s6-optimize's A66.1: TK.Util.Throttled's countdown, as it was written out here)
    p:SetScript("OnUpdate", TK.Util.Throttled(0.2, function() O.Show(p) end))
    -- s6-rules-dialogs' hook, as Modern's window: while the options show, the server's "saved" (S 0x21) is the tab's alert
    -- (NewOptionPane::HandlePacketEvent 0x00540DB0)
    p:HookScript("OnShow", function() H:DialogOptionPageShown(true) end)
    p:HookScript("OnHide", function() H:DialogOptionPageShown(false) end)
    return p
end

--- AddToLayer (0x005404D0), each accepted switch to the tab: page 0; OnActivate reads the volumes again.
function O.Activate(p)
    p.page = 0
end

--- MoveSelection (0x00541A20): a page back (-1) or on (1) within the two, its arrow drawn pressed at the next paint;
--- true (the tab's Page Up and Page Down are taken at either end: HandleKeyOrTextEvent returns true).
function O.Page(p, delta)
    if delta < 0 and p.page > 0 then
        p.page, p.pressed = p.page - 1, "back"
    elseif delta > 0 and p.page < PAGES - 1 then
        p.page, p.pressed = p.page + 1, "on"
    end
    O.Show(p)
    return true
end

--- One arrow's picture: field_11C8 / field_1240's [state] (0 normal, 1 pressed, 2 greyed).
local function arrow(p, key, tex, frame, state, x)
    p[key] = S.Picture(p, tex, "INVENBUT.EPF", frame + 7 * state, "INVENBUT.PAL", x, 269, "ARTWORK")
end

--- OnPaint: the page, its rows' states and the sliders on page 0 (UpdateVolumeSliderEnable 0x00541A90).
function O.Show(p)
    if not p:IsShown() then return end
    for i, hd in ipairs(HEADINGS) do
        for k, fs in ipairs(p.headings[i]) do
            if p.page == 0 then S.PenText(fs, p, hd[1], 1 + k, hd[2], S.TEXT) else fs:Hide() end
        end
    end
    for _, b in ipairs(p.rows) do
        local def, r = b.def, b.rect
        local here = def[6] == p.page
        b:SetShown(here)
        b.box:SetShown(here)
        b.shadow:SetShown(here)
        b.label:SetShown(here)
        if here then
            local on = def.on() and true or false
            if def[5] == 3 then
                S.Picture(p, b.box, "ONOFFBUT.EPF", on and 1 or 0, "BUTTON.PAL", r[1], r[2], "ARTWORK")
            else
                S.Picture(p, b.box, "RBUTTON.EPF", on and 0 or 1, "RBUTTON.PAL", r[1], r[2], "ARTWORK")
            end
            S.PenText(b.shadow, p, def[2], r[1] + 19, r[2] + 13, 6)
            S.PenText(b.label, p, def[2], r[1] + 18, r[2] + 13, S.TEXT)
        end
    end
    arrow(p, "backTex", p.backTex, 5, p.pressed == "back" and 1 or (p.page == 0 and 2 or 0), 147)
    arrow(p, "onTex", p.onTex, 6, p.pressed == "on" and 1 or (p.page == PAGES - 1 and 2 or 0), 166)
    p.pressed = nil
    for _, s in ipairs({ p.music, p.effects }) do
        s:SetShownAll(p.page == 0)
        if p.page == 0 then s:Draw() end
    end
end

return O
