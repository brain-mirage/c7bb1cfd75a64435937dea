-- s6-ui-core (round 82; shared in round 83, the owner's request of 2026-10-09: the red edge "on spells, not only the bars"):
-- Modern's red edge on a slot whose spell or item cannot be used now: the action bars' buttons, the spell book's rows and
-- the action wheel's segments, each part a switch of their page (markAether, markNoMana). Drawing only: a press goes as
-- before (TK.Game.Hotkeys, the book cell's input path), and nothing is asked of the server.

local H = __tk

local M = {}

M.COLOUR = { 0.95, 0.12, 0.1, 1 }

--- The kind and slot an action slot's aether and mark are read from: its action's (an item's first slot, or nil with none
--- left), a macro's shown action's (s6-macros).
function M.ShownAction(action)
    local kind, slot = GetActionInfo(action)
    if kind == "usermacro" then kind, slot = TK.MacroShownAction(slot) end
    return kind, slot
end

--- Whether what a slot holds is marked now (db: its page's settings): a spell or item in its aether (cooling), or a spell
--- whose learned cost (TK.SpellCost, from the player's own casts; none before its first cast) is more than the mana.
function M.Unusable(kind, slot, cooling, db)
    if not slot or (kind ~= "spell" and kind ~= "item") then return false end
    if db.markAether and cooling then return true end
    if kind ~= "spell" or not db.markNoMana then return false end
    local cost = TK.SpellCost(select(2, H:GetSpellSlot(slot)))
    return cost ~= nil and cost > select(4, H:GetUnitVitals("player"))
end

--- Draws a slot's edge texture red while marked, else in its own colour (normal); only on a change (owner.marked).
function M.Draw(owner, edge, marked, normal)
    if owner.marked == marked then return end
    owner.marked = marked
    local c = marked and M.COLOUR or normal
    edge:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

--- The aether running now on a spell or item slot: whether it cools, and when it ends (GetTime's), for a slot with no
--- Cooldown frame to say when it is done (the action wheel's segments).
function M.Cooling(kind, slot)
    if not slot or (kind ~= "spell" and kind ~= "item") then return false end
    local ok, start, duration = H:GetSlotCooldown(kind, slot)
    local ends = ok and start + duration or nil
    if ends and ends > GetTime() then return true, ends end
    return false
end

--- Adds a page's switches for the marks to the end of its rows, args (the action bars', the action wheel's, the Character
--- Window's for its spell book), fresh rows each call; their keys are on by default in each page's defaults.
function M.Args(args)
    args[#args + 1] = { type = "header", name = "Spells You Cannot Cast Now" }
    args[#args + 1] = { type = "toggle", key = "markNoMana", name = "Red Edge Without Enough Mana",
        desc = "A spell whose cost, as learned from your own casts, is more than your mana. A spell never cast is not marked." }
    args[#args + 1] = { type = "toggle", key = "markAether", name = "Red Edge in Its Aether" }
end

return M
