-- s6-interface-7x-b: 7.x's minimap button, the original's MiniMapButtonPane (ui/MapNamePane.cpp) at (6, 6)-(34, 34) on the
-- 7.x screen, in the frame layer over the map view's corner (MainMenuPane::InitializeMainUiGraph): MMAPBUT.EPF in
-- FRMPART.PAL, frame 1 while a press made on it is held over it, frame 0 otherwise (OnPaint 0x00503650,
-- HandlePointerOrMouseEvent 0x005036A0). Its place follows the scaled screen until the player moves it (edit mode, its
-- Layout tab). The minimap dialog the server's 70 opens is a dialog of the dialogs' look (the model's MiniMapDialog; Modern's
-- map window stands in for it, core/mapwindow.lua).
--
-- Wire: 4a's button is a push button whose click sends what m sends (UserPane::SendOpcode7CPacket: 7C while no minimap
-- dialog is open). The click is a left press on it and the release over it: the left press is used up there (case 1
-- returns true), so no map press happens under it; the release over it runs m's action, the minimap action, as the Modern
-- minimap's Map button does (interfaces/modern/panels/minimap/main.lua; the rules send 7C, DialogRules.MinimapKey); a
-- release off it sends nothing. Everything else is the map's under it: the pointer's moves (its hover and cursor), the right button and a
-- double click's second press (case 1 is the left press alone, MapNamePane.cpp:189; type 2 falls through), which the pane
-- declines, so a right press there is the map's right press (a look, the player menu) and a double press the map's. The
-- frame therefore claims the left button's single presses only (Frame:SetClaimButtons, SetPassesDoubles: s6-interface-7x-b
-- round 2, Astra's review of round 1: a double press had re-armed it for a second 7C) and takes no mouse otherwise. While the model's minimap dialog is
-- open nothing is run: that dialog is modal, and the original's button gets no press then. Changing which press or
-- release runs it, which button it takes, or when, changes what the server sees. s6-input (round 49, separation step 4b):
-- the click runs through the game layer's one minimap press (TK.Game.Minimap.Press, core/game/minimap.lua), which keeps
-- that gate.

local C = TK.GetComponent("7x.minimapbutton")
local S = require("interfaces.7x.skin")
local Screen = require("interfaces.screen")

local RECT = { 6, 6, 34, 34 }

function C:OnEnable()
    local f = CreateFrame("Frame", "TK7xMinimapButton", UIParent)
    f:SetFrameStrata("LOW")
    f:SetFrameLevel(10) -- the frame layer, over the map view
    f:SetSize(RECT[3] - RECT[1], RECT[4] - RECT[2])
    f:SetClaimButtons("LeftButton") -- the left button's presses only: the rest is the map's (above)
    f:SetPassesDoubles(true) -- and its single presses only: a double press is the map's (above)
    -- s6-input (round 51, Astra's self-review 51-2): every left release over it is its own, a press elsewhere's too
    -- (case 3 returns true for any release in it, MapNamePane.cpp:200), so a control lying under it gets none (no 41 or
    -- 3B 09)
    f:SetTakesEveryRelease(true)
    -- m's action, which the release runs (TK.Actions: C# freezes it as the input begins)
    TK.Actions:Set(f, "minimap")
    f:SetScript("OnMouseDown", function(_, button, double)
        if button ~= "LeftButton" or double then return end -- case 1 alone arms it
        f.held = true
        self:Paint()
    end)
    f:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        local click = f.held and f:IsMouseOver()
        f.held = false
        self:Paint()
        if click then TK.Game.Minimap.Press() end
    end)
    -- frame 1 only while the held press is over it (case 0, a move while pressed)
    f:SetScript("OnUpdate", function() if f.held then self:Paint() end end)
    f:Hide()
    self.frame = f
    self:Own(f)
    self.entry = Screen.Register(f, "7x.minimapbutton", "7.x Minimap Button", function() return self:DB().enabled == true end)
    self:Paint()
end

--- MMAPBUT's frame 1 while the press is held over it, else frame 0; drawn when it changes.
function C:Paint()
    local f = self.frame
    local frame = (f.held and f:IsMouseOver()) and 1 or 0
    if frame == f.shown then return end
    f.shown = frame
    f.art = S.Picture(f, f.art, "MMAPBUT.EPF", frame, "FRMPART.PAL", 0, 0, "ARTWORK")
end

function C:Layout() Screen.PlacePanel(self, 1024, 768, RECT[1], RECT[2]) end

function C:ApplySettings() self:Layout() end

Screen.Follow(C, "Layout")
