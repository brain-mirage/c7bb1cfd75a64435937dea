-- Actions (plan 5.9, D19). The UI attaches what the player can ask for to its controls and keys; C# freezes the action
-- of the control or key when a physical input begins (a mouse button goes down, a key is pressed, Enter in a box),
-- before any script runs, and a script can then only run that frozen action, once (A:RunFrozen). No script can make an
-- action run, change the one frozen for an input, or run one outside an input. A window's own request (D20) is attached
-- to its frame (A:SetOpen) and runs only when that frame becomes visible during an input.
--
-- What is sent is decided by C#: offline, the mock world plays casts and item uses; online, only actions with a rule
-- citing the original (4a) are sent (the D20 requests and the sound-effects switch for now). Every other action is
-- logged and the player is told.

local H = __tk

local A = {}
TK.Actions = A

-- What each kind is called in messages. The kinds are TK.Core.World.ActionKinds.
A.labels = {
    use = "Use", eat = "Eat", drop = "Drop", dropall = "Drop all", dropgold = "Drop gold", give = "Give",
    giveall = "Give all", givegold = "Give gold", throw = "Throw", wield = "Wield", barehands = "Bare hands",
    wear = "Wear", takeoff = "Take off", post = "Post", swapitems = "Move item", swapspells = "Move spell",
    pickup = "Pick up", cast = "Cast", attack = "Attack", emote = "Emote", say = "Say", shout = "Shout",
    whisper = "Whisper", ignore = "Ignore", unignore = "Hear again", invite = "Invite", ride = "Ride", look = "Look",
    open = "Open", refresh = "Refresh", boards = "Boards", mail = "Mail", userlist = "User list",
    helpmenu = "Help menu", helpmenu2 = "Help menu 2", minimap = "Minimap",
    -- s6-rules-items' kinds (head note 23).
    takeoffall = "Take off all", mix = "Mix", ["exchange:accept"] = "Accept exchange", ["exchange:money"] = "Offer gold",
    ["exchange:cancel"] = "Cancel exchange", power = "Power", partysearch = "Party search", ["partysearch:query"] = "Party note",
    macro = "Macro", -- s6-macros
}

--- Attaches an action to a control: what a physical press of it runs. Slots are 1-52; kind nil clears it.
function A:Set(frame, kind, slot, amount, text)
    H:SetFrameAction(frame.__h, kind or "", slot or 0, amount or 0, text or "")
end

--- Attaches the character's text macro id to a hotbar button: the host reads its line from the imported macros and
--- makes the descriptor, with the macro flag (review r4 finding 1). Nothing else can make one.
function A:SetMacro(frame, id)
    H:SetFrameMacro(frame.__h, TK.Characters.ref or "", id)
end

--- s6-macros: attaches one of the player's macros ("account:3", "char:1") to a button: a press runs its text as the
--- button holds it, so call it again after the macro changes (the macro window fires ACTIONBAR_SLOT_CHANGED).
function A:SetUserMacro(frame, ref)
    H:SetFrameUserMacro(frame.__h, TK.Characters.ref or "", ref)
end

function A:Clear(frame) self:Set(frame, nil) end

--- The original path a press of the control stands for ("hotkey", "spellbook", "inventory", "selflook"): the rules
--- tell some actions apart by it (s6-rules-core's EntryPath).
function A:SetPath(frame, path)
    H:SetFramePath(frame.__h, path or "")
end

--- s6-ui-bars: whether a key bound to the control runs its action while the control is hidden (an action bar's button).
function A:SetKeyWhileHidden(frame, on)
    frame.keyWhileHidden = on
    H:SetFrameKeyWhileHidden(frame.__h, on)
end

--- Attaches an action table ({ kind, slot, amount, text }) or clears it (nil).
function A:SetTable(frame, action)
    if action then self:Set(frame, action.kind, action.slot, action.amount, action.text) else self:Clear(frame) end
end

--- A window's own request (D20): it runs when the frame becomes visible during a physical input, and only then.
function A:SetOpen(frame, kind)
    H:SetFrameOpenAction(frame.__h, kind or "")
end

--- A key layer ("prompt", "settings", "classic" or "bindings"; s6-ui-settings: settings): key name to a control (it runs that control's action), to an
--- action table ({ kind, slot, amount, text }), or to false (the key is taken and runs nothing).
function A:SetKeyLayer(layer, map)
    local t = {}
    for key, v in pairs(map or {}) do
        if type(v) == "table" and v.__h then
            t[key] = v.__h
        elseif type(v) == "table" and type(v.macro) == "string" then
            t[key] = { macro = v.macro, character = TK.Characters.ref or "" } -- s6-macros: the host reads its text
        elseif type(v) == "table" and v.builtin then
            t[key] = { builtin = v.builtin } -- s6-input: the logic's own command (TK.Bindings.builtins)
        elseif type(v) == "table" and v.release then
            t[key] = { release = true } -- s6-input: a command that acts on its key's release too
        elseif type(v) == "table" then
            t[key] = { kind = v.kind or "", slot = v.slot or 0, amount = v.amount or 0, text = v.text or "" }
        else
            t[key] = false
        end
    end
    H:SetKeyLayer(layer, t)
end

--- Runs the action the physical input being handled froze, once, and tells the player what came of it. Returns C#'s
--- result: "ok", "cooldown", "mana", "empty", "unavailable" or "noinput" (no input, no action, or already run).
function A:RunFrozen()
    local r, kind = H:RunFrozenAction()
    -- Online the action is queued for the logic thread; what came of it is told later (TK_ACTION_DONE).
    if r == "noinput" or r == "queued" then return r end
    self:Tell(kind, r)
    return r
end

--- s6-input (plan D25): runs a control's action as it is now, as the physical input being handled, once: the action
--- wheel's pick on its key's release (a command registered with an up function). Returns what RunFrozen returns.
function A:RunFrame(frame)
    local r, kind = H:RunFrameAction(frame.__h)
    if r == "noinput" or r == "queued" then return r end
    self:Tell(kind, r)
    return r
end

--- Tells the player what came of an action (an offline one at once, an online one when the logic has run it).
function A:Tell(kind, r)
    -- A window's request (D20) and an option's echo are quiet: the window opens and the option changes either way.
    if kind:sub(1, 5) == "open:" or kind:sub(1, 7) == "option:" then return end
    local label = self.labels[kind] or kind
    if r == "unavailable" then
        if H:IsOnline() then
            UIErrorsFrame:AddMessage(label .. ": not sent yet, the game rules for it come later.", 1, 0.6, 0.2)
        else
            UIErrorsFrame:AddMessage(label .. ": offline, nothing is sent.", 1, 0.6, 0.2)
        end
    elseif r == "cooldown" then
        UIErrorsFrame:AddMessage(kind == "cast" and "That spell's aether is still running." or "That item's aether is still running.")
    elseif r == "mana" then
        UIErrorsFrame:AddMessage("Not enough mana.")
    end
end

-- An online action's outcome, once the logic thread has run it (review r6 finding 2).
TK.On("TK_ACTION_DONE", function(_, kind, r) A:Tell(kind, r) end)
