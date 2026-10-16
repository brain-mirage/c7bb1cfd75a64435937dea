-- The chat's logic every interface uses (s6-modular-g round 15, from Modern's chat frame,
-- interfaces/modern/panels/chatframe, as the owner's rule for the move puts what more than one interface uses at the
-- root): the original's chat colours: its colour pairs, the text palette, which pair colours a server line and the
-- whisper's rearrangement. Modern's chat frame, the colour dialog (components/dialogs/chatcolor.lua and 7.x's look of
-- it), the screenshot's line and Game Options' lines use them. Nothing here is drawn or sent.

local H = __tk

local Chat = {}
TK.Chat = Chat

-- ----- the colours -----

--- The colour pairs' categories (ChattingColorPane) and their defaults (Config.cpp:1669-1681): text, then outline, for
--- each; palette indexes of the text palette, BARAM.PAL (PaletteLib::GetTextPalette 0x00543D60). settings.toml keeps
--- them (chat.colors).
Chat.CATEGORIES = { "Talk", "Shout", "Whisper", "Group", "Clan", "System" }
Chat.DEFAULT_COLORS = { 0x8F, 0x80, 0x0E, 0x80, 0x0B, 0x80, 0x37, 0x80, 0xD0, 0x80, 0x0E, 0x80 }

--- Without the packs (no palette): each channel's colour, as the frame drew them before the pairs.
Chat.colours = {
    say = { 1, 1, 1 }, shout = { 1, 0.55, 0.25 }, whisper = { 1, 0.5, 1 }, group = { 0.55, 0.8, 1 },
    clan = { 0.4, 1, 0.5 }, notice = { 1, 0.9, 0.55 }, system = { 1, 0.95, 0.5 }, colored = { 1, 1, 1 },
    local_ = { 0.7, 0.9, 0.7 },
}

--- A text palette index as red, green and blue (0-1); nil without the packs.
function Chat:PaletteRGB(index)
    self.palette = self.palette or {}
    local c = self.palette[index]
    if c == nil then
        local ok, r, g, b = H:GetPaletteColour("BARAM.PAL", index) -- s6-optimize R62: the host's one palette call
        c = ok and { r, g, b } or false
        self.palette[index] = c
    end
    return c or nil
end

--- A colour the session hands as one number, 0xRRGGBB (a line in the packet's own colours: 0x0A kind 18, 0x0D kind
--- 4), as red, green and blue (0-1); nil for none (a negative number or nil). s6-optimize R62: the chat's game layer
--- and 5.x's chat each read it with their own copy before.
function Chat.Packed(c)
    if not c or c < 0 then return nil end
    return { math.floor(c / 65536) % 256 / 255, math.floor(c / 256) % 256 / 255, c % 256 / 255 }
end

--- The twelve indexes of the pairs, Talk's text and outline first.
function Chat:Colors()
    local t = {}
    for v in (H:GetChatColors() or ""):gmatch("%d+") do t[#t + 1] = tonumber(v) end
    if #t ~= 12 then return { table.unpack(Chat.DEFAULT_COLORS) } end
    return t
end

-- Which pair colours a channel's lines (ChattingPane::HandleChatPacketType10 0x0047FF80): 0x0A kind 4 Shout's (2), 0
-- Whisper's (3), 11 Group's (4), 12 Clan's (5), 5 System's (6). 0x0D's lines have fixed colours, so no code reads the
-- Talk pair (HandleServerSayPacket 0x0047FD70): kinds 0 and 3 are 143, kind 1 is 14, each outlined in 128. Only 0x0D's
-- lines carry a speaker, which tells its shouts from 0x0A kind 4's.
local PAIR = { shout = 2, whisper = 3, group = 4, clan = 5, system = 6 }

--- A line's text and outline palette indexes, or nil for a line the original's chat pane does not colour.
function Chat:LineIndexes(channel, speaker)
    if channel == "say" then return 143, 128 end
    if channel == "shout" and speaker and speaker ~= 0 then return 14, 128 end
    local pair = PAIR[channel]
    if not pair then return nil end
    local c = self:Colors()
    return c[pair * 2 - 1], c[pair * 2]
end

-- The whisper's (kind 0), group's (11) and clan's (12) rearrangement: NAME" (TITLE) text becomes NAME(TITLE)" text, with
-- ] and > for the other two (ChattingPane.cpp:463-545).
local MARKS = { whisper = '"', group = "]", clan = ">" }

function Chat.Rearrange(channel, text)
    local mark = MARKS[channel]
    if not mark or not text:find(mark .. " ", 1, true) then return text end
    local close = text:find(") ", 1, true)
    if not close then return text end
    local tail, line = text:sub(close + 1), text:sub(1, close)
    local open = line:find("(", 1, true)
    if not open then return text end
    local middle = line:sub(open)
    line = line:sub(1, open - 1)
    local at = line:find(mark .. " ", 1, true)
    if not at then return text end
    return line:sub(1, at - 1) .. middle .. mark .. tail
end

return Chat
