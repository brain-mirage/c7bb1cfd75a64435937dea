-- s6-devtools (round 5; the interface separation's step 5: docs/development/interface-separation.md 4.4, open question
-- 49): the original client's word wrap of its message lists, for any interface that draws one. Moved from 5.x's message
-- board (interfaces/5x/panels/board/main.lua, C.Cut, s6-interface-5x), which follows 4a's code line by line; 7.x's
-- messages pane has its own reading of the same function (interfaces/7x/panels/messages/main.lua, C.Wrap). Drawing
-- only: nothing here is sent.

local Wrap = {}

--- A text's lines as SystemMessagePane::AddWrappedText (0x00586B00; 4a SystemMessagePane.cpp:556-646) cuts it into
--- messages: the characters' advances (width(ch): the skin's TextWidth) add up from the line's start; a character that is
--- not a letter or a digit marks the place after it; a tab ends the line (the tab dropped); when the sum passes max
--- (160 in 7.5.2's pane, 184 in its legacy branch, 5.33's board) the line ends at the last mark, or before this character
--- without one; nothing after the last line's end makes no line. Characters beyond ASCII count as letters, as iswalnum
--- takes them.
function Wrap.Lines(text, max, width)
    local chars = {}
    for ch in (text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    local lines, sum, breakAt, lineStart, i = {}, 0, 1, 1, 1
    local function emit(to) lines[#lines + 1] = table.concat(chars, "", lineStart, to - 1) end
    while i <= #chars do
        local ch = chars[i]
        sum = sum + (width(ch) or 0)
        if #ch == 1 and not ch:match("%w") then breakAt = i + 1 end
        if ch == "\t" then
            emit(i)
            i = i + 1
            breakAt, sum, lineStart = i, 0, i
        elseif sum > max then
            if breakAt > lineStart then i = breakAt end
            emit(i)
            breakAt, sum, lineStart = i, 0, i
        else
            i = i + 1
        end
    end
    if lineStart < i then emit(i) end
    return lines
end

return Wrap
