-- s6-ui-core (after build 41; s6-optimize's audit): waiting for work done off the UI, for any part of the client (the
-- Library's file jobs, the profile picture's file dialog). Files are read, written and chosen off the UI (C#'s jobs,
-- LuaApi.Jobs.cs), so a click returns at once and never holds the game's input, its packets or its timers; what waits for
-- an answer is asked again each frame here until it has one. Moved from the Library's own (s6-library round 3, review r2
-- finding 1), TK.Library.Await, which now uses it.

local waits = {}
local waiter = CreateFrame("Frame", nil, UIParent)
waiter:SetScript("OnUpdate", function()
    for i = #waits, 1, -1 do
        local w = waits[i]
        local answer = w.ask()
        if answer ~= nil then
            table.remove(waits, i)
            w.done(answer)
        end
    end
end)

--- Calls done with the answer once ask returns one (anything but nil): ask is called each frame until then. A C# job's
--- answer is ask = function() return __tk:JobAnswer(id) end.
function TK.Await(ask, done)
    waits[#waits + 1] = { ask = ask, done = done }
end
