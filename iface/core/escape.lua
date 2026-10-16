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

local E = { cancels = {}, windows = {}, shown = 0 }
TK.Escape = E

--- Adds something pending that Escape cancels before any window closes. fn() returns true if it cancelled
--- something. order places it among the others (lower first; the bow draw and the map selection come first).
function E:AddCancel(name, order, fn)
    self.cancels[#self.cancels + 1] = TK.Mark({ name = name, order = order, fn = fn })
    table.sort(self.cancels, function(a, b) return a.order < b.order end)
end

--- Adds a window Escape closes when it is the topmost one open. close() defaults to hiding it. The window becomes
--- toplevel (WoW's SetToplevel): shown, it is raised above the other open windows of its strata, so the one shown
--- last is drawn on top, gets the mouse and closes first.
function E:AddWindow(frame, close)
    frame:SetToplevel(true)
    local w = TK.Mark({ frame = frame, close = close or function() frame:Hide() end, shownAt = 0 })
    self.windows[#self.windows + 1] = w
    frame:HookScript("OnShow", function()
        E.shown = E.shown + 1
        w.shownAt = E.shown
    end)
    if frame:IsShown() then
        E.shown = E.shown + 1
        w.shownAt = E.shown
    end
    return w
end

local strataIndex = {}
for i, s in ipairs({ "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }) do
    strataIndex[s] = i
end

--- The open window drawn on top: highest strata, then frame level (raised when shown), then the one shown last.
function E:Topmost()
    local best, bs, bl
    for _, w in ipairs(self.windows) do
        if w.frame:IsVisible() then
            local s = strataIndex[w.frame:GetFrameStrata()] or 0
            local l = w.frame:GetFrameLevel()
            if not best or s > bs or (s == bs and (l > bl or (l == bl and w.shownAt > best.shownAt))) then
                best, bs, bl = w, s, l
            end
        end
    end
    return best
end

function TK.HandleEscape()
    for _, c in ipairs(E.cancels) do
        if c.fn() then return true end
    end
    local w = E:Topmost()
    if w then
        w.close()
        return true
    end
    if TK.GameState:InWorld() then TK.GameMenu:Open() end
    return true
end

-- s6-interface-5x (round 13, the separation's step 11): a panel turned off takes its cancels and windows with it
TK.OnWithdraw(function(name, panel)
    TK.DropOwned(E.cancels, name, panel)
    TK.DropOwned(E.windows, name, panel, "frame")
end)
