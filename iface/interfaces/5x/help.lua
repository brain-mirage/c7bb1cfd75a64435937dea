-- s6-interface-5x-b (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md): 5.33's help line,
-- SimpleHelpPane (constructor 0x00441690, paint 0x004419F0; 4a's ui/HelpPane.cpp:236-330 is the same code). A right
-- press on a pane that has one (the clock, the icon row, the status pane's fields, the looks' two buttons) shows a short
-- text near the pointer for a while, one at a time: a new one replaces the last. Its box is the widest line + 10 wide and
-- (12 + 1) a line + 9 high, centred on the press, moved inside the pane it belongs to and then onto the 640 x 480
-- screen; filled in colour 1 with a 1-pixel frame in 0x80, its lines in 0x8F, the first one's pen at (5, 17), each next
-- 13 lower. A text's lines end at a CR, an LF or a tab.
--
-- s6-interface-5x-b (round 9, the interface separation's step 5): the box is the original client's
-- (interfaces/original/helppane.lua, Help.Show, Help.PlaceBox, Help.PointIn), made with 5.x's skin and screen; this file
-- keeps what is 5.x's: its panes' texts and their right press. The box's input rules are the kit's, W9's (WIRE there): a
-- press while it shows is used up, and a move, a key-down, a release or a wheel turn closes it and goes on, so a right
-- press's line lasts while that button is held. 5.x's own box before closed at a move and a key-down only.
--
-- Its texts are 7.5.2's string table's (LanguageMan, H:OriginalString): 7.5.2 keeps 5.33's help lines, two lines later
-- from 5.33's 187 (5.33's 187-207 are 7.5.2's 189-209), and has two lines, "Your Level." and "Your Path.", where 5.33 has
-- one (186). No 5.33 text is committed. Without the base set's string table nothing shows.
-- Drawing only, but for the kit's input rules: nothing here is sent, as neither client sends anything for a help line.

local S = require("interfaces.5x.skin")
local H = __tk
local Tips = TK.Game.Tips

-- WIRE: the box's input rules are the kit's, 7.5.2's (4a's SimpleHelpPane: HandlePointerOrMouseEvent 0x004C7450 uses up
-- a press wherever it lands; HandleKeyOrTextEvent 0x004C74A0 lets a key go on), not 5.33's: 5.33's own help line
-- (constructor 0x00441690) gives a press on (its mouse handler 0x00441B10 sets its closing timer at a left or right press
-- and returns false). 5.x keeps 7.5.2's input rules on purpose, as its other panes (to the server the client is
-- 7.5.2); giving it 5.33's rules changes what the server sees.
-- WIRE: 7.5.2's HourPane 0x004CEF30, IconsPane 0x004CF3E0, UserStatusPane 0x005B8A10 and UserLookPane 0x005A1580
-- create local help only on a type-4 single-right press; SelfLookPane 0x00568CB0 tests the bow before help hit-testing.
-- Shared Tips.ForPress receives the button, double-click flag and bow-first input. Changing which press shows a tip
-- changes which next press its catcher consumes and what the server sees.
local Help = require("interfaces.original.helppane")({ skin = S, screen = { width = S.WIDTH, height = S.HEIGHT }, roundOwner = true })

--- 7.5.2's string id's text (its line breaks as LF), or nil without the string table.
function Help.String(id)
    local s = H:OriginalString(id)
    if s and s ~= "" then return s end
end

--- A press on owner (OnMouseDown), or on from (a part of it that takes its own presses),
--- asks text(x, y) for the help at the press, in the owner's coordinates (5.33's pixels from its top left); a text
--- shows it for 5 s (Help.Show: centred on the press, in the owner and on the screen), nil shows nothing. bowFirst is
--- optional and is passed to the shared trigger along with the mouse button and double-click flag. The frame pressed
--- takes the pointer (EnableMouse).
function Help.OnRightPress(owner, text, from, bowFirst)
    from = from or owner
    from:EnableMouse(true)
    from:HookScript("OnMouseDown", function(_, button, double)
        local life = Tips.ForPress(button, double, bowFirst)
        if not life then return end
        local x, y = Help.PointIn(owner)
        local t = text(math.floor(x), math.floor(y))
        if t then Help.Show(owner, t, life) end
    end)
end

return Help
