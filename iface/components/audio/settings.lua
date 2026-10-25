-- The Sound settings page. It fills the UI's Sound node (core/settings.lua, TK.SoundNode): the values belong to this
-- computer (TK.Machine, "sound"), and the page is listed on the login screen too. A missing or mistyped value takes
-- its default.
-- s6-ui-core (round 54; the owner, 2026-10-05: "Sound should also have a general and extra pages like graphics will have.
-- Have the sliders under general. Add a Music Player and MIDI pages"; and Positional Audio "moved out of Experimental to
-- the new sound menu as an Advanced subpage"): Sound is a title with four subpages, General (TK.SoundNode, the sliders and
-- the general switches), Music Player, MIDI and Advanced (C:SettingsNodes). The keys are the same, so the settings carry
-- over. Every subpage is the music dialog's page (open:music), so moving between them keeps the dialog open.

local C = TK.GetComponent("audio")
local A = CS.TK.Unity.Audio.AudioHost

C.defaults = {}

C.soundDefaults = { master = 1, music = 0.7, effects = 0.8, midi = 0.7, backgroundMute = true, soundBank = "",
    effectsOn = true,
    -- s6-audio round 23 (the owner, 2026-10-03): ours, not the original's; how effects are heard, never what is sent
    maxEffects = 8, idle = 1, positional = false, edgeVolume = 0.5,
    -- s6-ui-core (build 41; the owner, 2026-10-05): Play Login Music, off by default (main.lua applies it)
    loginMusic = false,
    -- s6-ui-core (round 54; the owner, 2026-10-05): the thunder heard from its strike's side and distance (main.lua)
    positionalThunder = true }

--- The machine's sound table, with every key present.
function C:Sound()
    local s = TK.Machine:Get().sound
    for k, v in pairs(self.soundDefaults) do
        if type(s[k]) ~= type(v) then s[k] = v end
    end
    return s
end

local function volume(key, name)
    local arg = { type = "range", key = key, name = name, min = 0, max = 1, step = 0.05 }
    if key == "music" then arg.commit = function(_, v) C:CommitMusicSwitch(v) end end
    return arg
end

local function notInWorld() return not TK.GameState:InWorld() end

--- The original saves its Config at exit; the music player's settings are saved when they change.
local function saveClientSetting(kind, key, value)
    __tk["ClientSetting" .. kind](__tk, "sound", key, value)
    __tk:ClientSettingsSave()
end

-- s6-ui-core r66: remember changes made by the existing music dialog's model, through the same machine
-- table/client keys as Sound. This is saving/volume presentation only: never call source/folder/order setters here,
-- because FolderPathSelected 0x00529EE0 scans once in the Choose release and shares the wire's random stream.
function C:RememberMusicDialog(state)
    local s, dirty = self:Sound(), false
    if s.effects ~= state.effectsVolume / 100 then s.effects = state.effectsVolume / 100 dirty = true end
    if self.musicVolume ~= state.musicVolume / 100 then
        self:SetMusicVolume(state.musicVolume / 100) dirty = true -- existing helper keeps Config's mute flag
    end
    if dirty then self:ApplySettings() TK.Machine:MarkDirty() end
    local changed = false
    -- 4a 0x0052A310 saves SoundFreq separately from Off; persisting the displayed 0 changes its next alert/unmute
    -- boundary and later wire-shared draws. RememberMusicDialog only copies Config; it never commands playback.
    for _, item in ipairs({ { "Int", "music_frequency", state.frequency }, { "Int", "music_source", state.source }, { "String", "music_folder", state.folder }, { "String", "music_cd_drive", state.cd or "" },
        { "Bool", "play_random", state.order ~= 0 }, { "Bool", "play_repeat", state.repeatMode == 0 } }) do
        local kind, key, value = table.unpack(item)
        if __tk["ClientSetting" .. kind](__tk, "sound", key) ~= value then
            __tk["ClientSettingSet" .. kind](__tk, "sound", key, value) changed = true
        end
    end
    if changed then __tk:ClientSettingsSave() end
end

local function number(text)
    local n = tonumber(text)
    return n and math.floor(n) or nil
end

-- The switch and its child need share the live getter; F7 can change it without changing the saved flag.
local function effectsOn() return A.IsSoundEffectsEnabled() end

-- s6-ui-core (round 54): Sound's General: the sliders and the general switches (their explanations are tooltips now).
C.tabs = {
    { name = "General", args = {
        { type = "header", name = "Volume" },
        volume("master", "Master Volume"),
        volume("music", "Music"),
        volume("midi", "MIDI Music"),
        { type = "header", name = "Switches" },
        { type = "toggle", key = "backgroundMute", name = "Mute in the background",
          desc = "As the original. Off, the music track playing goes on." },
        -- s6-ui-next hook: the original's sound-effects switch (MusicControlDialog::OnControlCommand 0x00529790,
        -- control 1): its press and release go to the dialog model's music dialog, which sends 1B 01 0D and turns the
        -- effects on or off (core/settings.lua, S:MusicSwitch). It lives in the world, as the original's music dialog.
        -- s6-audio: it shows the audio logic's effects state, as the original's dialog shows SoundManager's
        -- (MusicControlDialog.cpp:104), so it reads Off after F7. (s6-world-view, merging main with the integration:
        -- the integration's press route, which replaced the option:soundeffects action, with s6-audio's state.)
        -- Changing this original press/release route changes what the server sees.
        { type = "toggle", key = "effectsOn", name = "Sound Effects On", width = "full",
          pointer = function(down, button, box) TK.Settings:MusicSwitch(down, button, box) end,
          get = effectsOn,
          hidden = function() return not TK.GameState:InWorld() end },
        -- s6-optimize (round 34): the effects are silent while the switch is off. Keep their values available at
        -- login too, where the original dialog's switch is hidden; the need reads the same live getter, including after F7.
        { type = "group", requires = { TK.Needs("Sound Effects On", effectsOn) }, args = {
            volume("effects", "Sound Effects"),
            -- s6-audio round 23: the voices effects play on, and the idle sounds' volume.
            { type = "range", key = "idle", name = "Idle Sounds", min = 0, max = 1, step = 0.05,
              desc = "Reading and snoring while a player is idle. 0 turns them off." },
            { type = "range", key = "maxEffects", name = "Max Sound Effects", min = 8, max = 32, step = 1,
              desc = "The original plays 8: a new one cuts off the oldest." },
        } },
    } },
    { name = "Test", args = {
        { type = "description", name = function() return A.Status() end },
        { type = "input", name = "Play effect (0-999)",
          set = function(_, text) local n = number(text); if n then A.PlayEffect(n) end end },
        { type = "input", name = "Zone music or track number",
          set = function(_, text) local n = number(text); if n then A.PlayZoneMusic(n, n, 100) end end },
        { type = "input", name = "MIDI track (1-12, 0 stops)",
          set = function(_, text) local n = number(text); if n then A.TestMidi(n) end end },
        { type = "break" },
        { type = "execute", name = "Title music", func = function() A.PlayTitleMusic() end },
        { type = "execute", name = "Enter world", func = function() C:EnterWorld() end },
        { type = "execute", name = "Map change (fade out)", func = function() A.ChangeMap() end },
        { type = "execute", name = "Skip to the end of the track", func = function() A.SkipToEndOfStream() end },
        { type = "execute", name = "Stop music", func = function() A.StopMusic() end },
        { type = "execute", name = "Refresh", func = function() end },
    } },
}

-- s6-ui-core (round 54): Sound's Music Player: Play Login Music, and in the world the music dialog's player.
local playerArgs = {
    -- s6-ui-core (build 41; the owner, 2026-10-05): whether the login screen's title music is heard (main.lua)
    { type = "toggle", key = "loginMusic", name = "Play Login Music",
      desc = "The title music on the login screen. The music in the game is not changed." },
    -- s6-audio round 10: the music dialog's player (MusicControlDialog, F8): the source, the MP3 folder, its order
    -- and repeat options, previous, pause and next (End plays the next track too). In the world, as the dialog. Each
    -- change is the audio logic's, and is saved as the original saves its configuration.
    { type = "header", name = "Music player", hidden = notInWorld },
    { type = "select", name = "Music Source", hidden = notInWorld,
      values = { { value = 0, text = "Zone music" }, { value = 1, text = "My MP3 folder" }, { value = 2, text = "Audio CD" } },
      get = function() return A.MusicSource() end,
      set = function(_, v)
          A.SetMusicSource(v)
          saveClientSetting("SetInt", "music_source", v)
      end,
      default = function() return __tk:ClientSettingDefaultInt("sound", "music_source") end }, -- s6-ui-settings
    { type = "description", hidden = notInWorld, name = function()
          local folder = A.MusicFolder()
          return "MP3 folder: " .. (folder ~= "" and folder:gsub("\\", "/") or "(none)")
              .. (A.MusicSource() == 2 and "\nAudio CDs are not played (no CD audio here): the CD source is silent." or "")
      end },
    -- s6-optimize (round 34): these three options affect playback only with the MP3 source. The scan still matches
    -- 4a SoundManager::ScanMusicDirectory (0x0057A890, C12): on attach and a new folder, Random Order draws once per
    -- file in EVERY source on the random stream the wire shares. Never gate those scans/draws on this playback need:
    -- changing them changes the random draws the server sees. AudioLogic and every setter below stay unchanged.
    { type = "group", requires = { TK.Needs("Music Source: My MP3 folder", function() return A.MusicSource() == 1 end) }, args = {
        { type = "input", name = "Choose the MP3 folder (its full path)", hidden = notInWorld,
          set = function(_, text)
              -- s6-ui-settings: "" (the page's reset; the box never sends it) is no folder, playing and saved alike
              if text == "" then A.ClearMusicFolder() else A.SetMusicFolder(text) end
              saveClientSetting("SetString", "music_folder", text)
          end,
          default = function() return __tk:ClientSettingDefaultString("sound", "music_folder") end }, -- s6-ui-settings
        { type = "toggle", name = "Random Order", hidden = notInWorld,
          get = function() return A.IsPlayRandom() end,
          set = function(_, on)
              A.SetPlayRandom(on)
              saveClientSetting("SetBool", "play_random", on)
          end,
          default = function() return __tk:ClientSettingDefaultBool("sound", "play_random") end }, -- s6-ui-settings
        { type = "toggle", name = "Repeat", hidden = notInWorld,
          get = function() return A.IsPlayRepeat() end,
          set = function(_, on)
              A.SetPlayRepeat(on)
              saveClientSetting("SetBool", "play_repeat", on)
          end,
          default = function() return __tk:ClientSettingDefaultBool("sound", "play_repeat") end }, -- s6-ui-settings
    } },
    { type = "execute", name = "Previous Track", hidden = notInWorld, func = function() A.PreviousTrack() end },
    { type = "execute", name = "Pause / Resume", hidden = notInWorld, func = function() A.TogglePauseMusic() end },
    { type = "execute", name = "Next Track", hidden = notInWorld, func = function() A.NextTrack() end },
}

-- s6-ui-core (round 54): Sound's MIDI: the sound bank (the MIDI volume is General's).
local midiArgs = {
    { type = "input", name = "SoundFont file (.sf2); a single - for the default",
      set = function(_, text)
          C:Sound().soundBank = text == "-" and "" or text
          C:ApplySettings()
      end,
      default = function() return C.soundDefaults.soundBank end }, -- s6-ui-settings: the page's reset
    { type = "description", name = function()
          local s = C:Sound().soundBank
          return "Setting: " .. (s ~= "" and s or "(default: GeneralUser GS from project/tools/get-soundbank.ps1)")
      end },
}

-- s6-ui-next hook: the switch follows the server's last 23 (byte 5), as the original's Config and open music dialog
-- take it (UserPane::ApplyServerOptionsPacket 0x005ABF30, MusicControlDialog::HandlePacketEvent 0x00529BE0); nothing
-- is sent for it (1B 01 0D goes only when the player changes the switch). s6-audio round 7: attached to the session, the
-- audio logic takes 0x23 and 0x08 itself (Config's and SoundManager's effects flags), so the value is only saved here;
-- until the session's setup attaches it (UI head note 22), it is applied from here as well.
TK.On("TK_SERVER_OPTIONS", function(_, soundEffects)
    C:Sound().effectsOn = soundEffects == 1
    TK.Machine:MarkDirty()
    if not A.IsAttached() then A.SetSoundEffectsEnabled(soundEffects == 1) end
    if TK.Settings:IsOpen() then TK.Settings:RefreshPage() end
end)

TK.SoundNode.tabs = C.tabs
TK.SoundNode.db = function() return C:Sound() end
TK.SoundNode.defaults = function() return C.soundDefaults end -- s6-ui-settings: the page's reset
TK.SoundNode.onChange = function(key, value) C:ApplySettings(key, value) end

-- s6-audio round 23 (the owner, 2026-10-03): the positional options were the Experimental tab's Sound page; s6-ui-core
-- (round 54; the owner, 2026-10-05) moved them to Sound's Advanced, with the thunder's own switch.
local function edgePercent() return math.floor(C:Sound().edgeVolume * 100 + 0.5) end

local function setSound(node, key, value)
    C:Sound()[key] = value
    TK.Machine:MarkDirty()
    C:ApplySettings()
end

-- s6-ui-core (round 54): what the Advanced page's controls need to have an effect, their (!) (core/settings.lua)
local positional = TK.Needs("Positional Audio", function() return C:Sound().positional end)

-- s6-ui-core (round 54; the owner, 2026-10-05: "you should be able to toggle Lightning Sounds to be positional here as
-- well. If not, the lightning sounds from Experimental don't use positional audio"): on, the thunder comes from its
-- strike's side; off, from the middle. Only its side: its delay and loudness are the strike's distance either way
-- (s6-effects' model, round 11: TK.WorldView.Thunder, AdvancedEffects.SetPositionalThunder in main.lua). Its needs are
-- set by C:SettingsNodes (below).
local positionalThunder = { type = "toggle", name = "Positional Lightning Sounds", default = true,
    desc = "The thunder from its strike's side. Off: from the middle.",
    get = function() return C:Sound().positionalThunder end,
    set = function(node, v) setSound(node, "positionalThunder", v and true or false) end }

local advancedArgs = {
    { type = "toggle", name = "Positional Audio", default = false,
      desc = "Creatures and players sound loudest where you stand, quieter toward the view's edge, and from their side. Music, the login's sounds and the weather (thunder too) are not changed.",
      get = function() return C:Sound().positional end,
      set = function(node, v) setSound(node, "positional", v and true or false) end },
    { type = "input", name = "Edge Volume (%)", live = true,
      desc = "A sound's volume at the view's edge, 0 to 100 % of its own.",
      get = function() return tostring(edgePercent()) end,
      set = function(node, text)
          local n = tonumber(text)
          if n and n >= 0 and n <= 100 then setSound(node, "edgeVolume", n / 100) end
      end,
      default = function() return tostring(math.floor(C.soundDefaults.edgeVolume * 100 + 0.5)) end,
      requires = { positional } },
    positionalThunder,
}

function C:SettingsNodes()
    -- s6-ui-core (round 60; s6-optimize's FOR r60, item 2): Positional Lightning Sounds needs the Weather page's master
    -- switch and Lightning, the needs advancedeffects' settings.lua makes (taken here, when every settings file is loaded)
    local effects = TK.GetComponent("advancedeffects")
    positionalThunder.requires = effects and { effects.weatherNeed, effects.lightningNeed } or nil
    --- A subpage of Sound: the machine's sound settings, at the login screen too, and the music dialog's page (its
    --- request, open:music, as General's: core/settings.lua, S:LeavesMusicFor).
    local function sub(id, title, order, args)
        return { id = id, title = title, parent = "Sound", order = order, category = "general", atLogin = true,
                 machine = true, request = "open:music",
                 db = function() return C:Sound() end, defaults = function() return C.soundDefaults end,
                 tabs = { { name = title, args = args } } }
    end
    return { sub("soundplayer", "Music Player", 921, playerArgs), sub("soundmidi", "MIDI", 922, midiArgs),
             sub("soundadvanced", "Advanced", 923, advancedArgs) }
end
