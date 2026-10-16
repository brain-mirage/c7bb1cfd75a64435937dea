-- s6-library round 24 (the owner, 2026-10-05: "in the Library, on the Characters and Players pages, hovering over an item
-- etc. should show a tooltip with the item's general stats, and clicking it should take you to the item page"): an
-- item's stats as the Library knows them, from the server's metadata tables (__tk:LibraryItemStats: the original's item
-- help box's rows), formatted here once, for the tooltip of a worn or carried item and for the Items page. Read only:
-- nothing is sent.

local H = __tk
local L = TK.Library

local DIM = { 0.62, 0.62, 0.66 }

--- The item's stats from the Library window's server: { lines ("Label: value"), description }; nil when that server's
--- tables do not have it, and nil, true while they are still being read. item: its picture and colour key, when known
--- (the tables are looked up by the item's own name the Library learned for it, else by name).
function L.ItemStats(name, item)
    local s = name and name ~= "" and L.server and H:LibraryItemStats(L.server, name, item or -1) or nil
    if not s then return nil end
    if s.loading then return nil, true end
    local lines = {}
    for _, r in ipairs(s.rows) do lines[#lines + 1] = r.label .. ": " .. r.value end
    return { lines = lines, description = s.description }
end

--- A worn or carried item's tooltip, for L.PlaceLink's tip or a gear slot's: its name, the slot it is worn in (kind,
--- when worn), its description and stats; "Unknown" when the Library knows nothing of it (no stats, and not known: no
--- Items page entry, so no link either). item: the item's picture and colour key (the Items page's, where that page
--- lists it); known: true when the Library knows the item all the same (a search's hit).
function L.ItemTip(name, kind, item, known)
    known = known or item ~= nil
    L.ItemStats(name, item) -- its server's tables start being read now, so they are ready when the pointer comes
    local waiting, last = false, nil
    local function tip(owner)
        last = owner
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:AddLine(name, 1, 1, 1)
        if kind and kind ~= "" then GameTooltip:AddLine(kind, DIM[1], DIM[2], DIM[3]) end
        local stats, loading = L.ItemStats(name, item)
        if stats and stats.description ~= "" then GameTooltip:AddLine(stats.description, 0.8, 0.8, 0.8) end
        for _, l in ipairs(stats and stats.lines or {}) do GameTooltip:AddLine(l, 0.9, 0.9, 0.9) end
        if not stats and not known and not loading then GameTooltip:AddLine("Unknown", DIM[1], DIM[2], DIM[3]) end
        GameTooltip:Show()
        -- Round 25 (the head's P2 on round 24): hovered while the tables were still being read, the tooltip is drawn
        -- again once they are, if it is still up for the last owner it was drawn for (a gear slot's icon and the name
        -- beside it share it: Astra's pass 2).
        if loading and not waiting then
            waiting = true
            TK.Await(function()
                local _, still = L.ItemStats(name, item)
                if not still then return true end
            end, function()
                waiting = false
                if GameTooltip:IsShown() and GameTooltip:GetOwner() == last then tip(last) end
            end)
        end
    end
    return tip
end

return L
