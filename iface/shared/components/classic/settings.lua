local C = TK.GetComponent("classic")

C.defaults = {
    enabled = false,
    -- s6-input (plan D24): whether the preset is in the key bindings, and the bindings it replaced.
    presetApplied = false,
    savedBindings = {},
    savedSecondary = {}, -- s6-ui-bars (review r1 P2): the secondary keys' marks of the replaced bindings
}
C.category = "general" -- s6-ui-settings (Astra's review): the settings list's General tab, beside Key Bindings

--- s6-input (round 48, Astra's review P2): while the preset is on, the bindings from before it wait in savedBindings and
--- come back when it is turned off (C:ApplySettings), so a command added since the profile was made (given: what the
--- profile was given already, core/db.lua) gets its default key there too, where free. GiveNewDefaults marks the profile
--- for saving when it gives one. s6-modular-g (round 19, the separation's step 8; interface-separation.md 7.1): the renamed
--- commands first (the original's hotkeys' carriers, TK.DB:RenameCommands), so a hotkey unbound there stays unbound.
function C:Migrate(saved, given)
    if type(saved.savedBindings) == "table" then TK.DB:RenameCommands(saved.savedBindings) end
    if saved.presetApplied == true and type(saved.savedBindings) == "table" then
        TK.DB:GiveNewDefaults(saved.savedBindings, given)
    end
    return false
end

C.tabs = {
    { name = "General Settings", args = {
        { type = "toggle", key = "enabled", name = "Enabled" },
        { type = "description", name = "Classic Commands gives the letter keys the original client's commands and prompts: d drop, D drop all, e eat, u use, w wield, W wear, t throw, h give, H give all, g invite, s status, f group, i bag, z collection, o open, r ride, m minimap, , pick up, ; look, : emote, \" whisper, ! shout, ' say, Ctrl+letter use, F9 ignore list, p post, c item order, C spell order, b boards, + spell book, F8 music, Q quit, and ? lists them in the chat." },
        { type = "description", name = "Turning it on writes the original's keys into the key bindings, where you can see and change them; turning it off puts back the bindings you had just before. It never acts while a text box has the keyboard. Every key the original client acts on does what it did there: s, + and i open the character window, the spell book and the bag." },
        { type = "description", name = "Walking: while it is on, the arrow keys walk (Ctrl+arrow shifts the view), as in the original, since W, A, S and D are commands then. While it is off, the Walk keys of the key bindings do (W, A, S and D by default, Ctrl with them shifting the view) and the arrows are free for other bindings." },
    } },
}
