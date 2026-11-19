-- Escape, in the original's order first (head note 12, plan D21; checked against 4a in s6-ui-next):
--
--   1. cancel what is pending, registered with E:AddCancel in this order:
--      - a modal prompt (order 2) and a right-click menu (4): the original's newest modal dialog, its command line
--        and its popups take Escape before the game screen does (DialogPane::HandleKeyOrTextEvent 0x0049E6E0,
--        LineInputPane, RightButtonMenuPane);
--      - then, as UserPane::HandleKeyOrTextEvent does, a drawn bow (it sends 13 04; order 10) and then an active map
--        selection (20);
--      - in this UI also an action held on the cursor (30) and an open drop-down list (40).
--   2. close the topmost open window (by strata, then frame level, then the most recently shown);
--   3. in the world, open the game menu (review F4), so Settings is always one key away.
--
-- Escape is handled before any key binding and cannot be rebound. Key-binding mode and a key box waiting for a key
-- see Escape first (it clears a binding there).
--
-- s6-ui-core (round 127, piece 5 of the Global Interface's C# shell): steps 1 and 2 are the shell's (Runtime/Shell/
-- Escape.cs: the cancels' order, the windows, which is on top), and step 3 too since round 170. This file keeps the names
-- and what each cancel and Lua window's close does, which the shell calls by id (__tk_shell "escape.cancel",
-- "escape.close"). WIRE: the order and "the first cancel that cancels something ends the key" are 4a's (Escape.cs says
-- where); changing them changes what the server sees.

local H = __tk
local E = { cancels = {}, windows = {} } -- in the order added; the shell keeps their Esc order
TK.Escape = E
local byId = {}

--- Adds something pending that Escape cancels before any window closes. fn() returns true if it cancelled
--- something. order places it among the others (lower first; the bow draw and the map selection come first).
function E:AddCancel(name, order, fn)
    local c = TK.Mark({ name = name, order = order, fn = fn })
    c.id = H:ShellEscapeCancel(name, order)
    byId[c.id] = c
    self.cancels[#self.cancels + 1] = c
end

--- Adds a window Escape closes when it is the topmost one open. close() defaults to hiding it. The window becomes
--- toplevel (WoW's SetToplevel): shown, it is raised above the other open windows of its strata, so the one shown
--- last is drawn on top, gets the mouse and closes first.
function E:AddWindow(frame, close)
    local w = TK.Mark({ frame = frame, close = close or function() frame:Hide() end })
    w.id = H:ShellEscapeWindow(frame.__h)
    byId[w.id] = w
    self.windows[#self.windows + 1] = w
    return w
end

--- The open window drawn on top: highest strata, then frame level (raised when shown), then the one shown last. A
--- window the shell closes itself (the game menu, round 170) has no record here: it comes back as { id = id } alone.
function E:Topmost()
    local id = H:ShellEscapeTopmost()
    if id == 0 then return nil end
    return byId[id] or { id = id }
end

-- s6-ui-core (round 170, U-64 step 1): all three steps are the shell's now (Escape.Key); the game menu's opening when
-- nothing took the key went with them. WIRE: the order is 4a's (Escape.cs); changing it changes what the server sees.
function TK.HandleEscape()
    H:ShellEscapeKey()
    return true
end

TK.ShellCalls = TK.ShellCalls or {}

-- The shell's calls, in its order: true ends the key (any true value of fn, as the cancels always returned).
TK.ShellCalls["escape.cancel"] = function(_, id)
    local c = byId[id]
    return c ~= nil and c.fn() and true or false
end

TK.ShellCalls["escape.close"] = function(_, id)
    local w = byId[id]
    if w then w.close() end
end

-- s6-interface-5x (round 13, the separation's step 11): a panel turned off takes its cancels and windows with it
local function dropped(e)
    byId[e.id] = nil
    H:ShellEscapeRemove(e.id)
end

TK.OnWithdraw(function(name, panel)
    TK.DropOwned(E.cancels, name, panel, nil, dropped)
    TK.DropOwned(E.windows, name, panel, "frame", dropped)
end)
