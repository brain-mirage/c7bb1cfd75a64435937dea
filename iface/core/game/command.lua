-- The experimental gateway's advisory face. These questions and listeners cannot execute an action or reserve a
-- physical input. The command is checked again when its existing binding runs on the logic thread.
TK.Game = TK.Game or {}
local G, H = TK.Game, __tk

--- Returns allowed (true/false, or nil when unknown), reason, and wait in milliseconds (nil for a state-dependent
--- wait). route is "key" (default) or "button". Unmoved commands/routes answer nil, "engine-decides", nil.
function G.Can(kind, slot, amount, route)
    local known, allowed, reason, wait = H:CanCommand(kind, slot or 0, amount or 0, route or "key")
    if not known then return nil, reason, nil end
    return allowed, reason, wait >= 0 and wait or nil
end

local listeners = {}

--- Listen for availability transitions of this command/route. Returns a function to remove this listener.
--- Countdown-only changes do not call fn; use Can for the current remaining wait. fn receives allowed, reason, wait.
function G.OnCan(kind, fn, slot, amount, route)
    local listener = { kind = kind, fn = fn, slot = slot or 0, amount = amount or 0, route = route or "key" }
    listeners[#listeners + 1] = listener
    return function()
        for i, value in ipairs(listeners) do
            if value == listener then table.remove(listeners, i); return end
        end
    end
end

TK.On("TK_COMMAND_AVAILABILITY", function(_, kind, slot, amount, route, known, allowed, reason, wait)
    -- Copy the listener list: a callback may unregister itself or another callback.
    local current = {}
    for i, listener in ipairs(listeners) do current[i] = listener end
    for _, listener in ipairs(current) do
        if listener.kind == kind and listener.slot == slot and listener.amount == amount and listener.route == route then
            if known then TK.SafeCall(listener.fn, allowed, reason, wait >= 0 and wait or nil)
            else TK.SafeCall(listener.fn, nil, reason, nil) end
        end
    end
end)

return G
