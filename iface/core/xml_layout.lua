-- Explicit geometry written by the visual designer. Keep it through a panel's later Lua Layout() calls.
-- XML construction and Edit Mode may still write geometry with Method/Call; ordinary unmarked frames are untouched.
local L = {}
local names = { "ClearAllPoints", "SetPoint", "SetAllPoints", "SetSize", "SetWidth", "SetHeight" }
local function keep() end
local function frameOf(obj)
    return type(obj) == "table" and obj.__h and TK.Wrap(obj.__h) or obj
end

function L.Hold(obj)
    local frame = frameOf(obj)
    if rawget(frame, "__xmlAuthoredLayout") then return end
    local methods = {}
    for _, name in ipairs(names) do
        local fn = frame[name]
        if type(fn) == "function" then
            methods[name] = { slot = rawget(frame, name), call = fn }
            frame[name] = keep
        end
    end
    -- The frame owns this record. Composite setters may close over their own frame; keeping that cycle local
    -- avoids retaining an unloaded widget through a module-wide registry.
    rawset(frame, "__xmlAuthoredLayout", methods)
end

function L.Has(obj) return rawget(frameOf(obj), "__xmlAuthoredLayout") ~= nil end

-- Call the actual setter without lifting the hold: a callback raised by that setter must not replace the
-- placement with the panel's default layout while an explicit XML/Edit Mode write is in progress.
function L.Method(obj, name)
    local methods = rawget(frameOf(obj), "__xmlAuthoredLayout")
    return methods and methods[name] and methods[name].call or obj[name]
end

function L.Call(obj, name, ...)
    return L.Method(obj, name)(obj, ...)
end

-- A player's own Edit Mode placement takes over a panel's default, as it does for interface layout.lua.
function L.Release(obj)
    local frame = frameOf(obj)
    local methods = rawget(frame, "__xmlAuthoredLayout")
    if not methods then return end
    for name, saved in pairs(methods) do frame[name] = saved.slot end
    rawset(frame, "__xmlAuthoredLayout", nil)
end

return L
