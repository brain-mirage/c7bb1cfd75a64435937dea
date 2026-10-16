-- s6-ui-core (round 52; s6-optimize's chat review, H5): the GM Terminal's part every interface shares, moved unchanged
-- from Modern's chat frame (interfaces/modern/panels/chatframe/terminal.lua, s6-play-modes round 4; the decision
-- docs/user-related/decisions/2026-10-05-gm-commands-only-from-the-terminal.md, the declared deviation C-16). An
-- interface's chat shows the Terminal as one of its views (Modern's: its chat frame's Terminal tab) and tells this module
-- about it (TK.Terminal.Provide); this module joins the views to the rules and to the server this client started:
--   - the rules' Terminal state: whether a view is the one shown, so its keys open the Terminal's line;
--   - on this client's own server, the character made a GM there (the console's makegm) once a session, while a view has
--     a Terminal, so the slash commands work at once;
--   - the console's output, and the lines entered in the Terminal, shown in every view that has a Terminal.
-- The tab itself, its menu and its colours stay the interface's.

local H = __tk

local Term = { views = {} }
TK.Terminal = Term

local consoleSeen = 0 -- the console lines already looked at (ServerHost.ConsoleCount)
local made = {}       -- the characters made GM in this session, by their server and name

local function any(field)
    for _, view in pairs(Term.views) do
        if view[field]() then return true end
    end
    return false
end

--- Lines of the Terminal into every view that has one: the text and the kind of line ("console", "entered", "problem"),
--- which the view colours its own way. s6-interface-5x (round 13's hotfix, Astra's self-review 13-2): a line shown is kept
--- with the chat's lines (TK.Game.Chat.Remember), so a view started later (Modern's chat frame, switched back to) shows it
--- again in its Terminal tab, without its command run again. Drawing only.
local function show(text, kind)
    local shown = false
    for _, view in pairs(Term.views) do
        if view.present() then
            view.show(text, kind)
            shown = true
        end
    end
    if not shown then return end
    TK.Game.Chat.Remember(function(owner, panel)
        for _, view in pairs(Term.views) do
            if TK.OwnedBy(view, owner, panel) then view.show(text, kind) end
        end
    end)
end

--- An interface's view of the Terminal, by its panel's id: present() whether the player has one there (Modern: a
--- Terminal tab added), shown() whether it is the view on screen now, show(text, kind) a line of it. The view calls
--- Follow when its shown state can change (as its tabs load, change and show), and MakeGM when the player adds a Terminal.
function Term.Provide(id, view)
    Term.views[id] = TK.Mark(view)
end

-- s6-interface-5x (round 13, the separation's step 11): a chat panel turned off takes its Terminal view with it
TK.OnWithdraw(function(name, panel)
    for id, view in pairs(Term.views) do
        if TK.OwnedBy(view, name, panel) then Term.views[id] = nil end
    end
end)

--- Into the rules: whether a Terminal view is the one shown. Wire (C-16): while it is, Enter, ' and the typing area open
--- the Terminal's line, and / opens it with / in it (ChatRules.OpenTerminal); that line is the one way a server command
--- leaves this client, said exactly as Talk's 0E 00 (4a SayInputPane::InvokeAcceptedAction). Moved unchanged: changing
--- when it is set changes which line a key opens, and so what the server sees.
function Term.Follow()
    H:SetTerminal(any("shown"))
end

--- On this client's own server, the character in the world made a GM there (the console's makegm, level 99: every
--- command), once a session, while a view has a Terminal. The console's answer shows in the Terminal. (The local
--- server's console, not the game's connection: nothing is sent to the game server.)
function Term.MakeGM()
    local ref, name = TK.Characters.ref, TK.Characters.name
    if not any("present") or not ref or not name or made[ref:lower()] or not H:IsOwnServer() then return end
    if H:ServerCommand("makegm " .. name) then made[ref:lower()] = true end
end

--- The console's new lines into the Terminal's views; the lines that came while no view had a Terminal are passed over.
TK.On("TK_SERVER_CONSOLE", function()
    local text, count = H:GetServerConsoleSince(consoleSeen)
    consoleSeen = count
    if not any("present") then return end
    for line in text:gmatch("[^\n]+") do show(line, "console") end
end)

-- A line entered in the Terminal (ChatRules.TerminalLine): the console's goes to this client's own server (its echo comes
-- back with the console's lines); the game's, already said by the rules, is shown in the Terminal.
TK.On("TK_TERMINAL_LINE", function(_, text, toConsole)
    if not toConsole then
        show("> " .. text, "entered")
    elseif not H:ServerCommand(text) then
        show("Not sent: the local server is not running.", "problem")
    end
end)
