-- The local item-help pane's input and lifetime, shared by its drawings. Moved unchanged from 7.x (round 9).
TK.Game = TK.Game or {}
local I = {}
TK.Game.ItemHelp = I

local newest, localSheet
--- WIRE: EventDispatcher::DispatchEvent 0x004A7130 asks the newest root pane first. Reusing a drawing must retain
--- that order across the local sheet and the server's SimpleHelpPane; changing it changes which game press is taken.
function I.Raise(f)
    if newest and newest ~= f and newest:IsShown() then
        newest:SetFrameLevel(199)
        newest.catcher:SetFrameLevel(199)
    end
    newest = f
    f:SetFrameLevel(200)
    f.catcher:SetFrameLevel(200)
end

--- Attach ItemHelpPane's catcher, key watcher and ten-second timer to a drawing.
function I.Attach(f, name)
    -- WIRE: ItemHelpPane::HandlePointerOrMouseEvent (0x004CCC40) takes every pointer event wherever the pointer is (4a
    -- offers each to the newest pane first, no hit test): a single press (types 1 and 4) closes it, a double press, a
    -- release and a wheel turn leave it up, and none reaches what is under it, so the map walks nowhere, nothing is
    -- clicked and no list scrolls or pages. A catcher over the screen under the box. Letting a press or a wheel turn
    -- through changes what the server sees. Round 7, Astra's self-review: the catcher takes the pointer for the input
    -- layer too (SetTakesPointer), so a wheel bound over the map runs nothing while it shows, and the 7.x panes that hand
    -- a release on by its place (the parcel strip's) leave it (__tk:IsPointerTaken()).
    f.catcher = CreateFrame("Frame", name, UIParent)
    f.catcher:SetFrameStrata("DIALOG")
    f.catcher:SetFrameLevel(199)
    f.catcher:SetAllPoints(UIParent)
    f.catcher:EnableMouse(true)
    f.catcher:EnableMouseWheel(true)
    f.catcher:SetTakesPointer(true)
    f.catcher:SetScript("OnMouseDown", function(_, _, double) if not double then f:Hide() end end)
    f.catcher:SetScript("OnMouseWheel", function() end)
    f.catcher:Hide()
    f:SetScript("OnHide", function() f.catcher:Hide() end)
    -- it goes at its time (OnTimer: 10 s)
    f:SetScript("OnUpdate", function(self) if GetTime() >= self.untilTime then self:Hide() end end)
    -- WIRE: HandleKeyOrTextEvent (0x004CCC80) deletes it at any key-down and returns false: the key goes on (not taken
    -- here). Taking it changes what the server sees.
    f:SetWatchesKeys(true)
    TK.On("GLOBAL_KEY_DOWN", function() if f:IsShown() then f:Hide() end end)
end

--- ItemHelpPane's ten-second lifetime starts when it opens (HelpPane.cpp, ItemHelpPane constructor/OnTimer).
--- WIRE: while alive its catcher prevents map/list inputs; changing this wait changes what the server sees.
function I.Show(f)
    -- WIRE: Singleton<ItemHelpPane> in 4a's constructor 0x004C82D0 replaces the old local sheet, including a mixed
    -- interface's other drawing. Keeping both alive changes which pane takes the next game press.
    if localSheet and localSheet ~= f and localSheet:IsShown() then localSheet:Hide() end
    localSheet = f
    f.untilTime = GetTime() + 10
    f:Show()
    -- WIRE: EventDispatcher::DispatchEvent 0x004A7130 offers the newest shown pane first, including when reused.
    -- Keeping an older help catcher above this one changes which input closes which pane and reaches the game.
    I.Raise(f)
    f.catcher:Show()
end

return I
