-- Classic Commands (plan D19, opt-in, off by default): the original's one-key commands and prompts
-- (UserPane::HandleKeyOrTextEvent 0x005A5BD0; docs/research/nexustk/ui-inventory.md, keys K-001-K-111 and prompts
-- P-01-P-32). A letter key opens a prompt ("Eat what?"), and the next letter names the slot; the command is then an
-- action, the same one the default UI's menus run.
--
-- Plan D24 (UI head note 37): Classic is a preset of the key bindings, not a layer of its own. Turning it on keeps
-- the bindings as they are, then writes the original's keys into them, where the Key Bindings page shows them: the
-- arrows walk (Ctrl+arrow shifts the view), the letters are the commands below. Turning it off puts the kept bindings
-- back. The commands go with their keys like any binding, so a key press freezes its action before any script sees
-- the key (plan 5.9). s6-input (round 34, after the freeze): the preset has every key the original's handlers take by
-- default (ui-inventory.md, "Keys"), so its c, C, p and b are the original's (item order, spell order, post, the
-- boards), and the character window, the spell book and the bag are its s, + and i; the default UI keeps C, P and B
-- (head note 15).

local C = TK.GetComponent("classic")
local W = TK.UI
local H = __tk
local B = TK.Bindings
local U = TK.Util

-- s6-input (round 8, head note 23): in a live session the rules' prompts are the one prompt authority. A command key
-- carries its kind without a slot, and the rules open the original's prompt ("Drop what?"), which its next key answers;
-- the prompt bar only shows the rules' prompt (the logic's line) and sends nothing itself. Offline (the mock world)
-- the prompts below are this component's own.

local function live() return H:IsLiveInput() end

-- ----- the one-key prompt -----
-- s6-modular-g (round 16, separation step 7): its text is drawn by an interface's prompt line (Modern's, interfaces/modern/
-- panels/prompt, which draws the rules' prompts too), told by TK_CLASSIC_PROMPT: the text, or nil when it closes.

--- Opens a prompt: the next key goes to onKey(key), and keys (key name -> action table or false) is what that key runs.
local function showPrompt(text, onKey, keys)
    C.pending = onKey
    C.promptText = text -- s6-interface-5x (round 14): for a prompt line loaded while it is open (step 11)
    TK.Actions:SetKeyLayer("prompt", keys or {})
    TK.FireEvent("TK_CLASSIC_PROMPT", text)
end

local function closePrompt()
    C.pending = nil
    C.promptText = nil
    TK.Actions:SetKeyLayer("prompt", {})
    TK.FireEvent("TK_CLASSIC_PROMPT", nil)
end

--- The 52 slot keys: A-Z are slots a-z (1-26), Shift+A-Z are slots A-Z (27-52).
local function slotKeys(kind)
    local keys = {}
    for i = 0, 25 do
        local k = string.char(65 + i)
        keys[k] = { kind = kind, slot = i + 1 }
        keys["SHIFT-" .. k] = { kind = kind, slot = i + 27 }
    end
    return keys
end

--- A prompt that takes a slot letter (a-z, A-Z) and runs kind on it; extra maps other keys to { action } or to fn.
local function slotPrompt(text, kind, extra)
    return function()
        local keys = slotKeys(kind)
        for k, v in pairs(extra or {}) do keys[k] = type(v) == "table" and v or false end
        showPrompt(text, function(key)
            if extra and type(extra[key]) == "function" then return extra[key]() end
            -- Only a key of this prompt: any other key froze its own action, which the prompt must not run.
            if type(keys[key]) == "table" then TK.Actions:RunFrozen() end
        end, keys)
    end
end

local function goldPrompt(kind, title)
    return function()
        closePrompt()
        TK.Game.Inventory.GoldPrompt(kind, title)
    end
end

local function textPrompt(title, text, kind)
    return function()
        W.Prompt({ title = title, text = text, maxLetters = kind == "invite" and 15 or 80,
            action = function(v) if v ~= "" then return { kind = kind, text = v } end end })
    end
end

local function emotePrompt()
    local keys = {}
    for _, e in ipairs(TK.Game.Emotes.list) do
        -- The original's letters are case-insensitive.
        keys[e[1]:upper()] = { kind = "emote", amount = e[3] }
        keys["SHIFT-" .. e[1]:upper()] = { kind = "emote", amount = e[3] }
    end
    showPrompt("Which expression? [a-p]", function(key)
        if keys[key] then TK.Actions:RunFrozen() end
    end, keys)
end

local function ignorePrompt()
    showPrompt("Ignore list - (A)dd, (D)elete", function(key)
        if key == "A" then textPrompt("Ignore", "Who do you wish to ignore?", "ignore")()
        elseif key == "D" then textPrompt("Hear again", "Who do you wish to hear?", "unignore")() end
    end, { A = false, D = false })
end

local function run() TK.Actions:RunFrozen() end

-- s6-input (round 34): Alt+t turns the object transparency over (Config::m_staticObjectTransparencyEnabled, no message;
-- UserPane.cpp:1368), the World View page's option (s6-ui-core round 83: Graphics' World View, "worldviewgraphics").
local function toggleTransparency()
    local view = TK.GetComponent("worldview")
    if view then TK.Settings:SetOption("worldviewgraphics", "objectTransparency", view:DB().objectTransparency ~= true) end
end

-- The commands: name, text, the original's key, what runs offline (the prompts are this component's own there), and
-- the action the key carries (live: the rules run it; a kind without a slot opens the rules' prompt). Gold: \ / $ in
-- the drop prompt, \ / in the give prompt, as the original. s6-input (round 35): a sixth field, 34, for a command whose
-- key joined the preset in round 34 (the migration in C:ApplySettings).
local commands = {
    { "CLASSICDROP", "Drop", "D", slotPrompt("What do you wish to drop, and no longer own? [a-Z, $ gold]", "drop",
        { ["\\"] = goldPrompt("dropgold", "Drop Gold"), ["/"] = goldPrompt("dropgold", "Drop Gold"),
          ["SHIFT-4"] = goldPrompt("dropgold", "Drop Gold") }), { kind = "drop" } },
    { "CLASSICDROPALL", "Drop All", "SHIFT-D", slotPrompt("Drop all what? [a-Z]", "dropall"), { kind = "dropall" } },
    { "CLASSICEAT", "Eat", "E", slotPrompt("Eat what? [a-Z]", "eat"), { kind = "eat" } },
    { "CLASSICUSE", "Use", "U", slotPrompt("Use what? [a-Z]", "use"), { kind = "use" } },
    { "CLASSICWIELD", "Wield", "W", slotPrompt("Wield what? [a-Z, - bare hands]", "wield", { ["-"] = { kind = "barehands" } }), { kind = "wield" } },
    { "CLASSICWEAR", "Wear", "SHIFT-W", slotPrompt("Wear what? [a-Z]", "wear"), { kind = "wear" } },
    { "CLASSICTHROW", "Throw", "T", slotPrompt("Throw what? [a-Z]", "throw"), { kind = "throw" } },
    { "CLASSICGIVE", "Give", "H", slotPrompt("Give what? [a-Z, \\ gold]", "give",
        { ["\\"] = goldPrompt("givegold", "Give Gold"), ["/"] = goldPrompt("givegold", "Give Gold") }), { kind = "give" } },
    { "CLASSICGIVEALL", "Give All", "SHIFT-H", slotPrompt("Give all what? [a-Z]", "giveall"), { kind = "giveall" } },
    { "CLASSICCAST", "Cast", "SHIFT-Z", slotPrompt("Cast which spell? [a-Z]", "cast"), { kind = "cast" } },
    { "CLASSICINVITE", "Invite", "G", textPrompt("Invite", "Name of new group member?", "invite"), { kind = "invite" } },
    -- s6-input (round 30, the gate's emote-keys): live, the rules' emotion prompt (UserPane's ':', EmotionInputPane), whose
    -- letter answers it each time; an emote action with amount -1 asks for it.
    { "CLASSICEMOTE", "Emote", "SHIFT-;", emotePrompt, { kind = "emote", amount = -1 } },
    { "CLASSICIGNORE", "Ignore List", "F9", ignorePrompt, { kind = "ignore" } },
    -- The status key: 4a's SelfLookPane takes 's' before UserPane's RequestLocalPlayerStatus while it is the active tab
    -- (SelfLookPane.cpp:1067, UserPane.cpp:1546). Wire: whether the key sends 2D 00.
    { "CLASSICSTATUS", "Status", "S", function()
        -- s6-interface-5x (round 12, step 1; Astra's re-review of round 11): with 4a's tab 0 the active tab the self look
        -- takes the key and nothing is sent, in every interface (TK.Game.Views.StatusKey: a side panel's views cycle;
        -- Modern's window shows or hides outside the key's input); otherwise the key opens the self look with its 2D 00
        if TK.Game.Views.StatusKey() then return end
        TK.Game.Views.Toggle("character")
    end, { kind = "open:character" } },
    { "CLASSICCOLLECTION", "Collection", "Z", function() TK.Game.Views.Toggle("collection") end, { kind = "open:collection" } },
    { "CLASSICHELP", "Classic Commands Help", "SHIFT-/", function() C:PrintHelp() end },
    -- s6-input (round 34): the rest of UserPane's keys (UserPane::HandleKeyOrTextEvent 0x005A5BD0): p PostInputPane,
    -- c ChangeItemSlotInputPane, C ChangeSpellSlotInputPane, Shift+Q and Alt+x the quit prompt (OpenQuitPrompt
    -- 0x005A94B0: QuitDialog), F8 the music dialog (1B 01 00 as it opens: TK.Settings:OpenMusic, as Original Commands'
    -- F8; s6-ui-core round 80), Alt+t the transparency.
    { "CLASSICPOST", "Post", "P", slotPrompt("Post what? [a-Z]", "post"), { kind = "post" }, 34 },
    { "CLASSICITEMORDER", "Change Item Order", "C", nil, { kind = "swapitems" }, 34 },
    { "CLASSICSPELLORDER", "Change Spell Order", "SHIFT-C", nil, { kind = "swapspells" }, 34 },
    { "CLASSICQUIT", "Quit", "SHIFT-Q", nil, { kind = "dialog:open", text = "QuitDialog" }, 34 },
    { "CLASSICMUSIC", "Music", "F8", function() TK.Settings:OpenMusic() end, { kind = "open:music" }, 34 },
    { "CLASSICTRANSPARENCY", "Object Transparency", "ALT-T", toggleTransparency, nil, 34 },
}
-- The live-only prompts: while the input is live the rules own them, and a key they did not take (the bow drawn) does
-- nothing here either. s6-input (round 18, the gate's player differences): Shift+Z is the rules' "Cast which spell?"
-- (CastSpellInputPane, whose answer leaves no key layer behind: v stays the target line). ", ! and ' are the chat frame's
-- commands on the rules' lines (s6-ui-chat, the preset below).
local rulesPrompt = { CLASSICDROP = true, CLASSICDROPALL = true, CLASSICEAT = true, CLASSICUSE = true, CLASSICWIELD = true,
    CLASSICWEAR = true, CLASSICTHROW = true, CLASSICGIVE = true, CLASSICGIVEALL = true, CLASSICINVITE = true, CLASSICIGNORE = true,
    CLASSICCAST = true, CLASSICEMOTE = true, -- s6-input (round 30): the emote prompt too
    CLASSICPOST = true, CLASSICITEMORDER = true, CLASSICSPELLORDER = true, CLASSICQUIT = true } -- s6-input (round 34)

-- The preset: every command above on its original key, the original's keys of the default UI's commands, walking on
-- the arrows, and Ctrl+a-z (slots 1-26) and Ctrl+Shift+A-Z (27-52) using items, except the original's Ctrl+n, r, v, w.
C.preset = {
    ["UP"] = "MOVEUP", ["DOWN"] = "MOVEDOWN", ["LEFT"] = "MOVELEFT", ["RIGHT"] = "MOVERIGHT",
    ["CTRL-UP"] = "VIEWUP", ["CTRL-DOWN"] = "VIEWDOWN", ["CTRL-LEFT"] = "VIEWLEFT", ["CTRL-RIGHT"] = "VIEWRIGHT",
    ["F"] = "TOGGLEGROUP", ["I"] = "TOGGLEBAG", ["O"] = "OPENOBJECT", ["R"] = "RIDE", ["M"] = "MINIMAPREQUEST",
    [","] = "PICKUP", ["SHIFT-,"] = "PICKUPALL", ["CTRL-,"] = "PICKUP3", [";"] = "LOOK", ["SHIFT-M"] = "MAIL",
    ["CTRL-R"] = "REFRESH", ["CTRL-W"] = "USERLIST",
    -- s6-ui-chat: ", ! and ' are the chat frame's commands on their original keys (the rules open the original's lines).
    ["SHIFT-'"] = "CHATWHISPER", ["SHIFT-1"] = "CHATSHOUT", ["'"] = "CHATCURRENT",
}
local later = {} -- s6-input (round 35): the keys that joined the preset in round 34
for _, c in ipairs(commands) do
    local name, fn = c[1], c[4]
    B:RegisterCommand(name, "Classic: " .. c[2], function()
        if live() and rulesPrompt[name] then return end
        if type(fn) == "function" then fn() else TK.Actions:RunFrozen() end
    end, c[5])
    if c[6] then later[c[3]] = name else C.preset[c[3]] = name end
end
for i = 0, 25 do
    local k = string.char(65 + i)
    local low, high = "CLASSICUSE" .. (i + 1), "CLASSICUSE" .. (i + 27)
    B:RegisterCommand(low, "Classic: Use item " .. k:lower(), run, { kind = "use", slot = i + 1 })
    B:RegisterCommand(high, "Classic: Use item " .. k, run, { kind = "use", slot = i + 27 })
    if not ({ N = true, R = true, V = true, W = true })[k] then C.preset["CTRL-" .. k] = low end
    C.preset["CTRL-SHIFT-" .. k] = high
end

-- s6-input (round 35): the preset as it was before round 34, which a profile may still hold (C:ApplySettings).
local presetBefore34 = U.Copy(C.preset)
for key, command in pairs(later) do C.preset[key] = command end

-- s6-input (round 34, after the freeze: the gate's boards scenarios met our bag on b): the original's other default keys
-- (ui-inventory.md, "Keys"): b the boards, + (the keypad's too) the spell tab, Alt+x the quit prompt, Ctrl+Alt+n the
-- names (MapPane's n under any modifiers but Shift). Space, Enter, End, F2-F7, Ctrl+Tab, / and the keypad's / are their
-- default keys, listed for their Shift forms below: a command the preset names loses its other keys (B:ApplyPreset).
for key, command in pairs({
    ["B"] = "BOARDS", ["SHIFT-="] = "TOGGLESPELLBOOK", ["NUMPADPLUS"] = "TOGGLESPELLBOOK", ["SHIFT-NUMPADPLUS"] = "TOGGLESPELLBOOK",
    ["ALT-X"] = "CLASSICQUIT", ["SPACE"] = "ATTACK", ["ENTER"] = "OPENCHAT", ["END"] = "MUSICNEXT", ["F2"] = "HELPMENU2",
    ["F3"] = "FRIENDS", ["F4"] = "FIXEDMOVEMENT", ["F5"] = "HEARWHISPERS", ["F6"] = "HEARSHOUTS", ["F7"] = "SOUNDTOGGLE",
    ["CTRL-TAB"] = "SELECTSELF", ["/"] = "OPENCHATSLASH", ["NUMPADDIVIDE"] = "OPENCHATSLASH", ["ALT-CTRL-N"] = "TOGGLENAMES",
}) do C.preset[key] = command end
-- UserPane's switch reads these keys the same with Shift: Space, Enter, End, F2-F8 and the keypad's / alone, and with
-- Ctrl or Alt the comma, the arrows and Tab.
for _, key in ipairs({ "SPACE", "ENTER", "END", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "NUMPADDIVIDE",
    "CTRL-,", "CTRL-UP", "CTRL-DOWN", "CTRL-LEFT", "CTRL-RIGHT", "CTRL-TAB" }) do
    local mods, bare = key:match("^(.-)([^-]+)$")
    C.preset[mods .. "SHIFT-" .. bare] = C.preset[key]
end
-- The digits with Ctrl or Alt, Shift too, and the keypad's (Event.cpp's table gives them the digits' codes, round 35):
-- the second and third bars' hotkeys. Ctrl and the left Shift with 3 or 4 is the screenshot (K-103). s6-modular-g (round
-- 19, the separation's step 8): bound to the game layer's carriers of slots 13-22 and 25-34 (TK.Game.Hotkeys), CLICK
-- bindings that keep a click's input path. Wire: changing what they name changes what the server sees.
for i = 0, 9 do
    local bar2, bar3 = TK.Game.Hotkeys.Command(12 + (i == 0 and 10 or i)), TK.Game.Hotkeys.Command(24 + (i == 0 and 10 or i))
    C.preset["CTRL-" .. i], C.preset["CTRL-NUMPAD" .. i] = bar2, bar2
    if i ~= 3 and i ~= 4 then C.preset["CTRL-SHIFT-" .. i] = bar2 end
    C.preset["ALT-" .. i], C.preset["ALT-SHIFT-" .. i], C.preset["ALT-NUMPAD" .. i] = bar3, bar3, bar3
end
-- MapPane's - and = (the keypad's - too) step a GM's brightness under any modifiers that leave them - and = (Shift alone
-- makes the main row's _ and +); nothing is sent.
for _, mods in ipairs({ "", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }) do
    C.preset[mods .. "-"], C.preset[mods .. "NUMPADMINUS"], C.preset[mods .. "="] = "BRIGHTNESSDOWN", "BRIGHTNESSDOWN", "BRIGHTNESSUP"
end
C.preset["SHIFT-NUMPADMINUS"] = "BRIGHTNESSDOWN"

--- The keys' list, a client line in the chat (s6-interface-5x hook: by chatframe's TK_CLIENT_MESSAGE, every interface's).
function C:PrintHelp()
    TK.FireEvent("TK_CLIENT_MESSAGE", "Classic commands: d drop, D drop all, e eat, u use, w wield, W wear, t throw, "
        .. "h give, H give all, Z cast, g invite, s status, f group, i bag, z collection, o open, r ride, m minimap, "
        .. ", pick up, ; look, : emote, \" whisper, ! shout, ' say, Ctrl+letter use, F9 ignore list, "
        .. "p post, c item order, C spell order, b boards, + spell book, F8 music, Q quit.", { 0.7, 0.9, 0.7 })
end

--- The key hook, offline: a pending prompt of this component's takes the next key.
function C:OnKey(key)
    if TK.KeyBindMode.active or not self.pending then return false end
    local fn = self.pending
    closePrompt()
    fn(key)
    return true
end

-- The rules' prompts (live) are drawn by an interface's chat or prompt line (TK.Game.Prompts; Modern's prompt line,
-- interfaces/modern/panels/prompt: s6-modular-g round 16, separation step 7).

function C:OnEnable()
    -- Escape closes the prompt first, as the original's command line takes Escape (plan D21).
    TK.Escape:AddCancel("classic", 3, function()
        if not C.pending then return false end
        closePrompt()
        return true
    end)
    TK.On("PLAYER_LEAVING_WORLD", closePrompt)
end

-- s6-input (round 34): the preset's version; one written in before round 34 is brought up to it once.
C.presetVersion = 2

--- s6-ui-core: the panels keep their other keys (I also opens the bag).
local function keeps(command) return command:match("^TOGGLE") ~= nil end

--- On: the bindings as they are are kept and the preset written in; off: the kept ones come back (UI head note 37).
function C:ApplySettings()
    local db = self:DB()
    if db.enabled then
        B.keyHook = function(key) return C:OnKey(key) end
        if not db.presetApplied then
            -- A binding held on a key the preset takes is let go first, so it is not left pressed.
            B:ReleaseOwned(function(bare)
                for k in pairs(C.preset) do
                    if k == bare or k:match("%-(.+)$") == bare then return true end
                end
                return false
            end)
            -- s6-ui-bars (review r1 P2): the secondary keys' marks are kept with the bindings, across reloads.
            db.savedBindings, db.savedSecondary = B:ApplyPreset(C.preset, keeps)
            db.presetApplied = true
            db.presetVersion = C.presetVersion -- s6-input (round 34)
            TK.DB:MarkDirty()
        elseif (db.presetVersion or 1) < C.presetVersion then
            -- s6-input (round 35, Astra's review of round 34): only what round 34 changed, on the keys the player left as the
            -- older preset wrote them: both presets written into the bindings kept from before Classic, compared key by key.
            -- A key the player bound since, and the kept table, stay as they are.
            local map, before, after = B:Map(), U.Copy(db.savedBindings), U.Copy(db.savedBindings)
            B:WritePreset(before, presetBefore34, keeps)
            B:WritePreset(after, C.preset, keeps)
            local function migrate(key)
                if before[key] ~= after[key] and map[key] == before[key] then map[key] = after[key] end
            end
            for key in pairs(before) do migrate(key) end
            for key in pairs(after) do migrate(key) end
            db.presetVersion = C.presetVersion
            TK.DB:MarkDirty()
            TK.FireEvent("UPDATE_BINDINGS")
        end
    else
        if B.keyHook then B.keyHook = nil end
        closePrompt()
        if db.presetApplied then
            B:RestorePreset(db.savedBindings, db.savedSecondary)
            db.savedBindings, db.savedSecondary = {}, {} -- s6-ui-bars
            db.presetApplied = false
            TK.DB:MarkDirty()
        end
    end
end
