-- s6-play-modes (round 4; the owner, 2026-10-05): the chat's Terminal tab, for GM (server) commands. Never there by
-- default: any tab's right-click menu adds it (Add Terminal) and closes it again (Close Terminal). While it is the tab
-- shown, Enter, ' and the typing area open the Terminal's line (the rules' ChatRules.OpenTerminal), and / opens it with
-- / in it. That line takes only typed keys, and it is the one way a server command leaves this client (the decision
-- docs/user-related/decisions/2026-10-05-gm-commands-only-from-the-terminal.md): such a line is said exactly as Talk's
-- line says it, so the server decides what it does (a character below the command's GM level says it out loud).
--
-- On the server this client started (Client Host: H:IsOwnServer), a line without the server's prefix is the server
-- console's (who, bc, makegm, kick...: H:ServerCommand), never the game's, and the character in the world is made a GM
-- there (the console's makegm) once the Terminal is there, so the slash commands work at once. The tab shows its own
-- lines, the console's output there, and the server's answers (notices and system lines).
--
-- s6-ui-core (round 52; s6-optimize's chat review, H5): this file is Modern's view of the Terminal now. What every
-- interface shares (the rules' Terminal state, makegm, the console's output and the lines entered) is
-- core/terminal.lua's (TK.Terminal), moved there unchanged; Modern's chat frame tells it about its tab. The tabs' logic is
-- tabs.lua's (the Terminal's kind and its tab), the menu tabbar.lua's.

local C = TK.GetComponent("chatframe")
local T = require("interfaces.modern.panels.chatframe.tabs")

-- The Terminal's kinds of line, in Modern's chat colours.
local COLOURS = { console = "local_", entered = "say", problem = "notice" }

TK.Terminal.Provide("chatframe", {
    -- a Terminal tab added, in a frame that shows. s6-play-modes (round 6, s6-optimize's H3): a tab saved in the character's
    -- tabs while Modern's frame is off (7.x's default) is no Terminal: no makegm, no console lines, until the frame shows
    present = function() return T:TerminalIndex() ~= nil and C.frame ~= nil and C.frame:IsShown() end,
    -- it is the tab shown, in a frame that shows: a hidden frame's Terminal tab opens nothing (Astra's review of round 4)
    shown = function()
        local tab, f = T:Current(), C.frame
        return tab ~= nil and tab.terminal == true and f ~= nil and f:IsShown()
    end,
    -- (round 12 fix: the colours are TK.Chat's since s6-modular-g round 15; C.colours was gone)
    show = function(text, kind) C:AddLine(text, TK.Chat.colours[COLOURS[kind]], nil, nil, "terminal") end,
})
