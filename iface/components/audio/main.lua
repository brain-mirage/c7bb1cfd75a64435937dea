-- The sound's side of the UI: passes the Sound settings to C#, plays the title music on the login screen and the
-- zone music in the world, and keeps the music's playback volume. The login screen stands for the original's main menu.
-- s6-play-modes (round 8, interface-separation step 4): the click, the effects, the music switch and the End key's next
-- track are the game layer's (core/game/sound.lua, TK.Game.Sound).

local C = TK.GetComponent("audio")
local A = CS.TK.Unity.Audio.AudioHost

-- The preview's mock world has no zone music of its own: it plays zone 901, a random (.LSR) playlist.
C.previewZone = 901

function C:OnEnable()
    A.SetInWorld(TK.GameState:InWorld()) -- s6-audio (round 27): a new Lua (a restart, a reload) starts from its own state
    -- The Sound page's effects switch shows the audio logic's effects state, which F7, the window's focus and the
    -- server's options turn too: an open page follows it. A change of Config's "Music" marks the machine settings to be
    -- saved, as the original saves its configuration at exit whatever changed.
    if not self.watch then
        self.watch = CreateFrame("Frame", "TKAudioWatch", UIParent)
        self.watch:SetScript("OnUpdate", function()
            local on = A.IsSoundEffectsEnabled()
            if on ~= C.effectsShown then
                C.effectsShown = on
                if TK.Settings:IsOpen() then TK.Settings:RefreshPage() end
            end
            -- s6-ui-core (round 80; s6-qa's next60 play-test, problem 4): the Music Player's choices (source, folder, order,
            -- repeat) are the audio logic's, which on a session takes them as input on its thread a moment after the page
            -- asked (AudioLogic.Run), so the page redrew with the old ones: an open page follows them as they change.
            -- Drawing only: nothing is sent or drawn on the random stream.
            if TK.Settings:IsOpen() then
                local p = C.playerShown or {}
                local source, folder, random, again = A.MusicSource(), A.MusicFolder(), A.IsPlayRandom(), A.IsPlayRepeat()
                if p[1] ~= source or p[2] ~= folder or p[3] ~= random or p[4] ~= again then
                    C.playerShown = { source, folder, random, again }
                    TK.Settings:RefreshPage()
                end
            end
            -- s6-interface-7x-b (round 11): online, the shared MusicControlDialog constructor (4a 0x00528E60)
            -- owns this reset before 1B 01 00.
            -- Play Offline has no dialog model: the page stands in for its constructor there. Reset only its pause
            -- flag, without resuming a retained stream; nothing is sent. Do not duplicate the online reset: changing
            -- its event order changes what the server sees.
            if not C.dialogHooked and TKSettingsRequest then
                C.dialogHooked = true
                TKSettingsRequest:HookScript("OnShow", function() if not A.IsAttached() then A.OpenMusicDialog() end end)
            end
            local music = A.IsMusicConfigOn()
            if C.musicFlagSeen ~= nil and music ~= C.musicFlagSeen then
                TK.Machine:MarkDirty()
                -- Music back on (F7, the focus) while the slider shows it off: the slider shows the playback volume.
                local s = C:Sound()
                if music and (s.music or 0) <= 0 and C.musicVolume then
                    s.music = C.musicVolume
                    C.musicLevel = s.music
                    if TK.Settings:IsOpen() then TK.Settings:RefreshPage() end
                end
            end
            C.musicFlagSeen = music
        end)
    end
end

--- The Sound settings, applied. With a key, the player changed that option on the Sound page: the effects switch is
--- ApplySoundEffectEnabled (0x0052A2D0), and Music applies its volume here while CommitMusicSwitch handles the row's
--- mute state on release/Enter (0 is off; leaving 0 is on; changes between levels above 0 are volume alone). Without one
--- (start-up, a refresh), only the volumes and the bank: the switches are the audio logic's, which F7, the window's focus
--- and the server turn too.
function C:ApplySettings(key, value)
    local s = self:Sound()
    -- The playback volume is the original's MusicVolume, which it loads apart from the Music flag (SoundManager.cpp:127)
    -- and which a mute keeps: the slider's level, or while the slider shows the music off (0), the last level above 0,
    -- which the save keeps as music_volume.
    if (s.music or 0) > 0 then
        self.musicVolume = s.music
    elseif not self.musicVolume then
        self.musicVolume = math.max(0, math.min(100, __tk:ClientSettingInt("sound", "music_volume"))) / 100
    end
    local volumeKey = key
    -- Sound page 0's Music row is off; keep its last volume for reapplication and let MusicSwitch handle the player change.
    if key == "music" and (s.music or 0) <= 0 then volumeKey = nil end
    A.Configure(s.master, self.musicVolume, s.effects, s.midi, s.backgroundMute, s.soundBank, volumeKey)
    -- s6-audio round 23: our options; they change how effects are heard, never a draw or a send.
    A.SetMaxSoundEffects(math.floor(s.maxEffects + 0.5))
    A.SetIdleVolume(s.idle)
    A.SetPositionalAudio(s.positional, s.edgeVolume)
    -- s6-ui-core (round 54): Sound > Advanced's Positional Lightning Sounds, the thunder's side only (s6-effects' Thunder)
    CS.TK.WorldView.AdvancedEffects.SetPositionalThunder(s.positionalThunder ~= false)
    -- s6-ui-core (build 41; the owner, 2026-10-05): Play Login Music decides whether the login screen's title is heard,
    -- the active interface which title (core/entering.lua). Only what is heard changes: the audio logic still opens, fades
    -- and ends the title track, with its draws on the session's random stream (AudioHost.SetTitleMusic), so nothing sent
    -- or timed changes with it.
    if s.loginMusic == true then A.SetTitleMusic(TK.Entering.TitleTrack()) else A.SetTitleMusic(0) end
    -- WIRE: NewOptionPane::ApplyEffectAndMusicOptions (0x00541120) leaves positive-volume edits alone after F7.
    -- Keep the committed level during a drag; untagged reapplication refreshes it. Changing this can open a stream
    -- and draw from the shared random sequence, changing what the server sees.
    if key ~= "music" then self.musicLevel = s.music end
    if key == "effectsOn" then
        A.SetSoundEffectsEnabled(value == true)
    end
end

--- Commit the Sound page's Music mute state on its release or Enter input; positive volume still applies while dragging.
--- The original's Music switch is NewOptionPane::ApplyEffectAndMusicOptions (0x00541120); its volume is
--- NewOptionPane::ApplyVolumeChange (0x00540490). Only an accepted zero-crossing toggle may open the stream and draw on
--- the session's shared random sequence; moving it outside physical input changes what the server sees.
function C:CommitMusicSwitch(value)
    local was = self.musicLevel
    self.musicLevel = value or 0
    if self.musicLevel <= 0 then A.SetMusicOn(false)
    elseif was ~= nil and was <= 0 then A.SetMusicOn(true) end
end

--- s6-interface-7x-b (round 7; a marked addition for 7.x's options page, interfaces/7x/panels/side/options.lua): the
--- The music's volume alone, 0 included, as 4a's slider sets it (ScrollVolumePane::NotifyValueChange -> NewOptionPane::
--- ApplyVolumeChange 0x00540490 -> ApplyVolumeSettings, OptionPane.cpp:796-827: SoundManager::SetStreamVolume). Config's
--- "Music" flag is left as it is (the Music row's and F7's), so 0 is a silent stream, not the music off as on the Sound
--- page. There is no immediate packet or draw; its fade steps affect later C11 shared-RNG order, which the server sees.
local function setMusicVolume(self, v, key)
    self:Sound().music = v
    self.musicVolume = v
    self:ApplySettings(key) -- no key: reapply volumes only; a keyed player edit still leaves the flag branch alone
end

function C:SetMusicVolume(v) setMusicVolume(self, v) end

--- The in-game volume slider's player edit: keep its key on the existing ApplySettings path for AudioLogic.Run.
function C:ChangeMusicVolume(v) setMusicVolume(self, v, "musicVolume") end

--- The preview's world, without a server: the music fades out and starts again (RestartMusic(3000)) and the preview
--- names its zone. With a server the game's session does both from its own events (the accepted login, packet 0x19
--- kind 1) on the logic's side, and these two calls are ignored, so they can never add a rand() draw.
function C:EnterWorld()
    A.EnterWorld()
    A.PlayZoneMusic(self.previewZone, 0, 100)
end

-- End: the next track of the MP3 folder (UserPane.cpp:1726-1735; a CD's next track in the original). Wire: a track opened
-- is a draw on the random stream (TK.Game.Sound.NextTrack); the command stays here for its place on the Key Bindings page.
TK.Bindings:RegisterCommand("MUSICNEXT", "Next Music Track", function() TK.Game.Sound.NextTrack() end)
TK.DB.defaultBindings["END"] = "MUSICNEXT"

-- At start-up the login screen shows unless a UI reload happened in the world (TK.Login:Start): the main menu plays
-- its title track once.
TK.On("PLAYER_LOGIN", function()
    if __tk:GetSessionAccount() == "" then A.PlayTitleMusic() end
end)

TK.On("PLAYER_ENTERING_WORLD", function() C:EnterWorld() end)

-- Leaving the world stops the MIDI song (MapPane::ExitToMenuTeardown).
TK.On("PLAYER_LEAVING_WORLD", function() A.PlayMidi(0) end)

TK.On("TK_GAME_STATE", function(_, state, was)
    -- s6-audio (round 27): the title an interface leaves silent (core/entering.lua) is the login's; in the world the music
    -- is heard, the title going on there as the world's music included (AudioHost.SetInWorld). Only what is heard.
    A.SetInWorld(state == "world")
    if state == "login" and was == "world" then
        A.PlayTitleMusic()                -- a new main menu after Log Out
    elseif state == "charcreate" then
        A.OpenCharacterCreation()         -- the original stops the music for character creation
    end
end)
