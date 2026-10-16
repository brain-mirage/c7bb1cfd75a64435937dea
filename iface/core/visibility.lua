-- Shared show/hide and fade behaviour for component frames, following Bartender's options:
--
--   enabled        the frame exists and is shown
--   alwaysHide     Visibility: never shown, except in edit mode so it can still be moved
--   showModifier   Visibility: "none", or only while SHIFT / CTRL / ALT is held
--   alpha, scale   General: its alpha and scale
--   fadeOut        General: fade to fadeOutAlpha when the mouse is not over it, after fadeOutDelay seconds
--
-- One driver checks the registered frames every frame and eases alpha changes.

local V = { frames = {} }
TK.Visibility = V

local defaults = {
    enabled = true, alwaysHide = false, showModifier = "none",
    alpha = 1, scale = 1, fadeOut = false, fadeOutAlpha = 0.1, fadeOutDelay = 0,
}
V.defaults = defaults

--- Adds the common options to a component's defaults.
function V.Defaults(extra)
    local d = TK.Util.Copy(defaults)
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

--- Registers a frame to follow its settings table (read again on every check, so it may be replaced).
--- cond, if given, is one more condition outside edit mode (the target frame: while there is a target); it is
--- checked every frame, so it should only read a cached value.
function V:Attach(frame, getDB, cond)
    self.frames[frame] = { get = getDB, cond = cond, alpha = nil, leftAt = 0 }
    -- The component whose OnEnable or ApplySettings attaches it owns it (TK.ReplaceComponent).
    if TK.Components.current then TK.Components.current:Own(frame) end
    self:Apply(frame)
end

function V:Detach(frame)
    self.frames[frame] = nil
end

-- s6-interface-5x (round 13, the separation's step 11): the frames of a panel turned off, destroyed, are not followed
TK.OnWithdraw(function()
    for frame in pairs(V.frames) do
        if TK.IsDead(frame) then V.frames[frame] = nil end
    end
end)

local function modifierOk(m)
    if m == "SHIFT" then return IsShiftKeyDown() end
    if m == "CTRL" then return IsControlKeyDown() end
    if m == "ALT" then return IsAltKeyDown() end
    return true
end

local function targetAlpha(frame, state, db, now)
    local alpha = db.alpha or 1
    if db.fadeOut and not TK.EditMode.unlocked then
        if frame:IsMouseOver() then
            state.leftAt = nil
        else
            state.leftAt = state.leftAt or now
            if now - state.leftAt >= (db.fadeOutDelay or 0) then alpha = db.fadeOutAlpha or 0.1 end
        end
    end
    return alpha
end

local function wantShown(db, state)
    if db.enabled == false then return false end
    if TK.GameState and not TK.GameState:InWorld() then return false end
    if TK.EditMode.unlocked then return true end
    if state.cond and not state.cond() then return false end
    return not db.alwaysHide and modifierOk(db.showModifier)
end

--- Applies scale and visibility now, and alpha immediately (no easing).

function V:Apply(frame)
    local state = self.frames[frame]
    if not state then return end
    local db = state.get()
    if not db then return end
    frame:SetScale(db.scale or 1)
    state.shown = wantShown(db, state)
    frame:SetShown(state.shown)
    state.alpha = targetAlpha(frame, state, db, GetTime())
    frame:SetAlpha(state.alpha)
end

--- Re-applies every registered frame (after entering or leaving the world, or edit mode).
function V:ApplyAll()
    for frame in pairs(self.frames) do self:Apply(frame) end
end

local driver = CreateFrame("Frame", nil, UIParent)
driver:SetScript("OnUpdate", function(_, elapsed)
    -- Checked every frame, so showing by modifier feels instant; alpha changes are eased. The state is kept here,
    -- so a frame with nothing to do costs no call into C# (the review's allocation note).
    local now
    for frame, state in pairs(V.frames) do
        local db = state.get()
        if db then
            local shown = wantShown(db, state)
            if shown ~= state.shown then
                state.shown = shown
                frame:SetShown(shown)
            end
            if shown and (db.fadeOut or state.alpha ~= (db.alpha or 1)) then
                now = now or GetTime()
                local target = targetAlpha(frame, state, db, now)
                local a = state.alpha or target
                if a ~= target then
                    local step = elapsed * 4
                    if math.abs(target - a) <= step then a = target
                    elseif target > a then a = a + step else a = a - step end
                    state.alpha = a
                    frame:SetAlpha(a)
                end
            end
        end
    end
end)
