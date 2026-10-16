MR-TK (Public-Test)

Start MR-TK.exe and log in to the Dev server (wow.mentalrage.net), the first server in the list.

GETTING THE BUILD

  Download build-<version>.zip from the GitHub release and unpack it anywhere. It holds everything: the program,
  the interface, the game's art (data\packs) and the dev server's Library and map cache (core\prebuild).
  GitHub's green "Code > Download ZIP" button and the release's "Source code" archives do NOT hold the art:
  a client unpacked from them says it has no art packs.

THE FOLDERS

  Shipped with the build (an update replaces them):
    core\         the program: Unity's player, our modules (core\modules), the MIDI sound bank (core\soundbank),
                  the tile hints, the dev server's prebuilt Library and map cache (core\prebuild), build-info.json
    iface\        the interface: its Lua, its data, its pictures (iface\art)
    data\packs\   the game's art
    docs\         the third-party notices and licences, and the player's guides:
                  docs\Macros.md (making macros, every command, examples)
    tools\        tools\rebuild_cache.exe, and tools\remote-protocol-host-server\ (see its README.md)

  Yours (no build contains them; an update never touches them):
    config\       what applies on every server: settings.toml, your profiles, macros, spell icons,
                  config\plugins\ (plugins for every server)
    servers\      one folder per server, named after the server: its Library, its own plugins, and a folder
                  per character (put your profile picture, <name>.jpf, in the character's folder)
    logs\         each window's log, logs\crash-reports\
    screenshots\  your screenshots
    cache\        maps and tables the client keeps; delete it freely, it is made again

  MonoBleedingEdge\ and UnityCrashHandler64.exe are hidden beside MR-TK.exe: Unity needs them there.

  The local server (Client Host, Dedicated Server) is not part of the Public-Test build.

UPDATING

  Unpack the new build's zip over this folder (or delete the shipped folders first: core\, iface\, data\, docs\,
  tools\, MR-TK.exe, MonoBleedingEdge\, UnityCrashHandler64.exe). Your folders stay as they are.

COMMAND LINE (MR-TK.exe ...)

  --userdata <folder>   another folder for config\, servers\, logs\, screenshots\ and cache\
  --server HOST:PORT    log in to this server instead of the saved one
  --login NAME:PASSWORD fill in the login and send it once connected
  --packs <folder>      the game's art somewhere else
  --mods <folder>       plugins for every server from another folder
  --lua <folder>, --assets <folder>, --modules <folder>   another interface, its pictures, other modules
