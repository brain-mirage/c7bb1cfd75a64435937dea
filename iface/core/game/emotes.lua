-- s6-interface-5x (round 12; docs/development/interface-separation.md, step 2 and section 5.6): the game layer's emotes,
-- the original's sixteen expressions, which it offers only through a one-key prompt (":" then a-p;
-- EmotionInputPane::SendEmotionPacket 0x005B2F70 sends 1D with the byte below). Modern's emote menu, Classic Commands'
-- prompt and the gate's driver read them here.

TK.Game = TK.Game or {}
local E = {}
TK.Game.Emotes = E

-- The prompt's letter, the name the original's help lists (strings 15-30), and the byte of 1D. Wire: the byte is what
-- the server gets for the letter; changing it changes the emote the server sees.
E.list = {
    { "a", "Laughter", 0x00 }, { "b", "Grief", 0x01 }, { "c", "Shame", 0x02 }, { "d", "Affection", 0x03 },
    { "e", "Boredom", 0x04 }, { "f", "Sleepiness", 0x05 }, { "g", "Surprise", 0x06 }, { "h", "Rage", 0x07 },
    { "i", "Sarcasm", 0x08 }, { "j", "Shrug", 0x09 }, { "k", "Annoyed", 0x0A }, { "l", "Dance", 0x0B },
    { "m", "Respect", 0xFE }, { "n", "Triumph", 0xFF }, { "o", "Strange", 0x0C }, { "p", "Kiss", 0x0D },
}

--- The byte 1D sends for an emote's letter (a-p), or nil.
function E.Byte(letter)
    for _, e in ipairs(E.list) do
        if e[1] == letter then return e[3] end
    end
end

--- An emote control: the emote with its 1D byte, run by the control's click (TK.Actions:RunFrozen).
function E.Action(b, byte) TK.Actions:Set(b, "emote", nil, byte) end

return E
