-- The client's state (head note 6): "login" (the login screen, the first state), "charcreate" (character creation)
-- or "world". Component frames show only in the world (TK.Visibility), and key bindings act only there.

local G = { state = "login" }
TK.GameState = G

function G:Get() return self.state end

function G:InWorld() return self.state == "world" end

function G:Set(state)
    if state == self.state then return end
    local was = self.state
    self.state = state
    TK.Visibility:ApplyAll()
    TK.FireEvent("TK_GAME_STATE", state, was)
end

-- s6-optimize (round 6; docs/user-related/decisions/2026-10-03-windows-built-at-world-load.md): the windows whose first
-- opening was a hitch are built, hidden, while the world loads, so that opening costs what a later one does. Online that
-- is when the login is accepted (the 02 at which 4a builds its game screen's panes, InitializeMainUiGraph), while the
-- login screen waits for the transfer; offline, and after a reload in the world, as the world is entered. The same
-- objects and names, each shown when the player opens it, as before; nothing is sent. Each is built once.
local function buildWindows()
    TK.Game.Views.BuildAll()       -- the game's windows and pages, each registered by its own file (TK.Game.Views.BuildAhead)
    TK.Settings:BuildBindingRows() -- the Key Bindings page's rows, about 280 ms of its first selection (round 9)
end
TK.On("TK_SESSION_STATE", function(_, state) if state == "Accepted" then buildWindows() end end)
TK.On("PLAYER_ENTERING_WORLD", buildWindows)
