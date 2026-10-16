-- s6-modular-g (round 16, separation step 7; interface-separation.md 4.3): the prompt line's switch, on by default.
-- 7.x's and 5.x's first profiles leave it off, as their own chats draw every prompt kind (G3, Y3); a profile made
-- before it has it on, and their migrate leaves it so (decision 2026-10-05-first-profiles-only-their-own-panels).

local C = TK.GetComponent("prompt")

C.defaults = { enabled = true }

C.tabs = { { name = "General Settings", args = {
    { type = "toggle", key = "enabled", name = "Enabled" },
    { type = "description", name = "Shows a prompt (\"Eat what?\") where no chat shows it." },
} } }
