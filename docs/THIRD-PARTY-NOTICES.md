# Third-party notices

This build of the NexusTK UI preview contains the third-party software, fonts and graphics listed here. Each
one's full licence is in the `licenses/` folder next to this file. `project/build-ui-preview.ps1` copies them into
every build and fails if one is missing or differs from its source.

| Component | Version | Used for | Licence | Licence file |
|---|---|---|---|---|
| **xLua** (Tencent), with **Lua 5.3** | 2.1.16 (tag `2.1.16_android_16kb`) | the Lua runtime (`xlua.dll`, `libxlua.so`, `XLua` C#) | MIT, with the notices of the components xLua includes | `licenses/xLua-LICENSE.txt` |
| **Liberation Sans** (Red Hat), as shipped with Unity's TextMeshPro | TMP essential resources of com.unity.ugui 2.6.0 | the UI font | SIL Open Font License 1.1 | `licenses/LiberationSans-OFL.txt` |
| **Twemoji** graphics | 17.0.3 (`jdecked/twemoji`) | effect icons, window tabs, menu icons, the minimap's weather, mail and parcel icons (`assets/emoji/twemoji/`) | CC-BY 4.0 (graphics); MIT (code, not used) | `licenses/Twemoji-CC-BY-4.0.txt`, `licenses/Twemoji-MIT.txt` |
| **KayKit Adventurers** character pack (Kay Lousberg, www.kaylousberg.com), the Knight and the Rogue | 1.0, commit `672074b7` of `KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0` | the `3d-v1` module's stand-in characters, the Rogue for women since s6-modular-b round 8 (its bundle, `Modules/3d-v1/3d-v1.bundle`, in every build; the models fetched by `tools/modular/get-3d-model.py` when the build is made) | CC0 1.0 | `licenses/KayKit-Adventurers-CC0.txt` |
| **NLayer** (Mark Heath, Andrew Ward and contributors) | 3.0.0 | the MP3 music decoder (`NLayer.dll`) | MIT | `licenses/NLayer-LICENSE.txt` |
| **MeltySynth** (Nobuaki Tanaka), with code from C# Synth and TinySoundFont | 2.4.1 | the MIDI synthesizer (`MeltySynth.dll`) | MIT | `licenses/MeltySynth-LICENSE.txt` |
| **ScaleFX** (Sp00kyFox) | the five `scalefx-pass` shaders, 2016-2017 | the World View's Upscaling method ScaleFX (`TK.Core.Upscale.ScaleFx`, a C# port of the passes) | MIT | `licenses/ScaleFX-LICENSE.txt` |
| **GeneralUser GS** SoundFont bank (S. Christian Collins) | 2.0.3 | the MIDI instruments; a loose file beside the build, `data/soundbank/GeneralUser-GS.sf2`, fetched by `project/tools/get-soundbank.ps1` | GeneralUser GS License v2.0 | `data/soundbank/GeneralUser-GS-LICENSE.txt`, beside the bank |

## Attribution

Emoji graphics from Twemoji (https://github.com/jdecked/twemoji), copyright Twitter, Inc. and other contributors,
licensed under CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/). The PNG files are used unchanged, except the
backpack (`1f392.png`), which the client shows with its red body and pocket recoloured brown.

Liberation Sans is a trademark of Red Hat, Inc., used here only to name the font.

The Unity engine and its packages are covered by Unity's own licence terms.
