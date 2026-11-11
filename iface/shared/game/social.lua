-- s6-interface-5x (round 12; docs/development/interface-separation.md, step 2 and section 5.6): the game layer's social
-- data and actions, whatever an interface draws: the group as the server lists it (0x63 02) and the ignore list, read by
-- Modern's Social window and 7.x's side panel group page alike (they read the group two ways before: the group panes'
-- list and the party frames' units).

local H = __tk

TK.Game = TK.Game or {}
local S = {}
TK.Game.Social = S

--- The group as the group panes list it: every member of the last 0x63 02 in its order, the player's own record
--- included, as 4a's NewGroupPane lists them (s6-interface-7x-b, Astra's review of its round 1): each
--- { name, hp, hpMax, mp, mpMax, id, active }; active (s6-interface-7x-b round 8, a marked edit): the record's flag
--- byte (UnitState.Active), which NewGroupPane draws as the name in colour 12.
function S.GroupMembers()
    local list = {}
    for i = 1, H:GetNumGroupMembers() do
        local _, name, hp, hpMax, mp, mpMax, id, active = H:GetGroupMember(i)
        list[i] = { name = name, hp = hp, hpMax = hpMax, mp = mp, mpMax = mpMax, id = id, active = active }
    end
    return list
end

--- The ignored names of the character in the world, as the session holds them (none offline).
function S.Ignored()
    local list = {}
    for name in string.gmatch(H:GetBlockList() or "", "[^\n]+") do list[#list + 1] = name end
    return list
end

-- The actions the prompts' OK carries (TK.Actions; the rules send them). Wire: the action kinds are what the server
-- sees: invite 2E with the name (the original's g), ignore 0D 02 and hear again 0D 03 (its F9 list).

--- Invite name to the group (2E), or nil for no name.
function S.InviteAction(name) if name ~= "" then return { kind = "invite", text = name } end end

--- Ignore name (0D 02), or nil for no name.
function S.IgnoreAction(name) if name ~= "" then return { kind = "ignore", text = name } end end

--- Hear name again (0D 03), or nil for no name.
function S.UnignoreAction(name) if name ~= "" then return { kind = "unignore", text = name } end end

return S
