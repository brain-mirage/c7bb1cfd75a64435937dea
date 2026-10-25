-- s6-play-modes (round 8; docs/development/interface-separation.md, step 4 and section 5.11): the game layer's sound, what
-- every interface's panels and the tools call for the client's own sounds and the music switch. Moved from the audio
-- component (components/audio/main.lua), where the click and the effects existed only after its OnEnable; here they exist
-- as the file loads. The audio component keeps the Sound pages, passes their settings to C# and keeps the playback volume
-- (MusicVolume, SetMusicVolume).
--
-- Wire: the music's draws. Music off opens no stream, so a zone playlist draws no further on the main rand() stream
-- (MidiPlayer::Disable and Enable, MidiPlayer.cpp:256-270; AudioLogic.SetMusicOn). Moving that switch changes the random
-- stream the client's later packets use, which the server can see. End advances a folder track without a packet or an
-- immediate random draw (UserPane::HandleKeyOrTextEvent 0x005A5BD0, UserPane.cpp:1726-1735); keep that silence and its
-- existing input order. Playlist-end draws are a separate later stream notification.

local A = CS.TK.Unity.Audio.AudioHost

TK.Game = TK.Game or {}
local S = {}
TK.Game.Sound = S

--- The UI's buttons' click (core/widgets.lua): effect 0x198 (AudioHost.ClickEffect), the original's tab and dialog
--- sample. None while the effects are off (F7, the switch, the window in the background), as SoundManager::PlaySample.
--- Draws nothing.
function S.PlayClick() A.PlayClick() end

--- An effect by id (0-999), the UI's own sounds (the menu's Exit 0x192, a dialog's open 0x198). Draws nothing.
function S.PlayEffect(id) A.PlayEffect(id) end

--- Config's "Music" (the options' Music row, F7 and the window's focus write it; the machine settings save it as
--- sound.music): the audio logic's flag.
function S.MusicOn() return A.IsMusicConfigOn() end

--- The playback volume the save keeps as music_volume (the original's MusicVolume, apart from the flag,
--- SoundManager.cpp:275), also while the Sound page's slider shows the music off; the audio component keeps it.
function S.MusicVolume()
    local audio = TK.GetComponent("audio")
    return audio and audio.musicVolume
end

--- The options' Music row (NewOptionPane row 16, then ApplyEffectAndMusicOptions 0x00541120): Config's flag, and the music
--- muted or back, the volume kept. Local: nothing is sent. Wire: off, no stream opens (see the file's head).
function S.SetMusicOn(on) A.SetMusicOn(on == true) end

--- The music's playback volume alone (0-1, 0 included), as 4a's options slider sets it (NewOptionPane::ApplyVolumeChange
--- 0x00540490, then ApplyVolumeSettings: SoundManager::SetStreamVolume): Config's Music flag is left as it is, so 0 is
--- a silent stream, not the music off. The audio component keeps it (C:ChangeMusicVolume). No immediate packet or draw;
--- later fade steps and C11 shared-RNG order still follow the original volume control.
function S.SetMusicVolume(v)
    local audio = TK.GetComponent("audio")
    if audio then audio:ChangeMusicVolume(v) end
end

--- The End key (UserPane.cpp:1726-1735): the next track of the MP3 folder (a CD's next track in the original), the music
--- dialog's pause left as it is. Wire: a track opened is a draw (see the file's head).
function S.NextTrack() A.AdvanceTrack() end

return S
