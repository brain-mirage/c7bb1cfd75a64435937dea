# remote-protocol-host-server

The remote protocol's host without the game (s6-peer round 16; the owner, 2026-10-06). It does what a client with
**Act as a host** on does, in the same code (TK-Core's `HeadlessHost` around `RemoteNode`):
- it knows who is connected and where;
- it keeps the subscription table and fans the answers out;
- it keeps the player list;
- in normal builds it introduces players for Secure (Secure itself never goes through a host);
- it keeps each client's Ignore list.

It opens no game, no game connection and no window of the client's, and it has no player of its own, so it is never on
its own player list. It uses the remote protocol's port, not a game server's, so it also runs beside a Dedicated Server
on the same PC.

## Starting it

Double-click `remote-protocol-host-server.exe`, or run it from a command prompt. It runs until Ctrl-C or until its window
is closed; then it says bye to every client and stops.

The window shows:
- what it listens on, and for how long it has been up;
- the connected clients: name, server, address, and how long each has been connected;
- the traffic: the subscriptions by category, the requests routed and answers fanned out, the introductions for Secure,
  and the Ignore lists (Public-Test leaves out Secure and its introduction counts);
- the latest events. The same lines go to the log file.

## Settings

`remote-protocol-host-server.toml`, beside the exe. With no file, it writes one with the defaults. A bad file is kept as
`remote-protocol-host-server.toml.bad`, and the defaults are used and written in its place. Restart the tool after a
change.

| Setting | Default | What it does |
|---|---|---|
| `port` | `3007` | The TCP port clients connect to (the Remote-Protocol page's Port). |
| `bind` | `"0.0.0.0"` | The address it listens on; `"0.0.0.0"` is every IPv4 address of the PC. |
| `log` | `"remote-protocol-host-server.log"` | The log file, beside the settings file unless a full path is given. |

The other settings on a client's Remote-Protocol pages (Command Privileges, the Plugins switches, Connections, the Ignore
list) are a player's, and this host has no player.

Command-line options override the file: `--config <file>` (another settings file), `--port <port>`. `--help` lists them.

## Connecting a client to it

In each client, under **Settings > Plugins > Remote-Protocol**:
1. Turn on **Enable the remote protocol** (it also needs **Enable unsafe plugins**).
2. Leave **Act as a host** off.
3. Under **Connections**, **Add by address**: the PC running this tool, as `host:port`, for example `192.168.1.5:3007`,
   or the owner's own, `mentalrage.net:3007`. Just `192.168.1.5` uses port 3007.

The entry shows **host** and **active host** once it is connected, and the client appears in the tool's window. As with an
in-game host, players reach each other through it by character name.

Port 3007 is the default because the owner's router forwards 3000-3009 to the dev server's PC, and the dev server takes
3000-3006. **On the same PC as a client:** the client listens on its own Port too (3007 by default). Give the client
another port, for example 3008, and leave this tool on 3007. Players on other PCs need the tool's port open in that PC's
firewall (and forwarded on the router, from outside the home network).
