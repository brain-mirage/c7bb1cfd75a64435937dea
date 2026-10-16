-- s6-interface-7x-b: 7.x's clock, the original's HourPane (ui/HourPane.cpp) at (830, 736)-(885, 751) on the 7.x screen, in
-- the frame layer (MainMenuPane::InitializeMainUiGraph). It shows the game hour of the server's last 0x20 (the logic's
-- clock: __tk:GetGameHour, -1 before the first one) as frame g_hourFrameTable[hour / 2 % 12] of TIME.EPF in TIME.PAL, one
-- picture a two-hour period (OnPaint 0x004CF010); nothing before the first hour (4a fills colour 0, which draws
-- nothing). A right press on it shows the hour in 4a's plain tooltip for 5 seconds, "<string 77> : HH"
-- (HandlePointerOrMouseEvent 0x004CEF30). Its place follows the scaled screen until the player moves it (edit mode, its
-- Layout tab).
--
-- Wire: nothing is sent. The clock only reads 0x20 (HandlePacketEvent 0x004CEEE0 never takes it); its right press is used
-- up there (it returns true on the clock), as this frame takes it.

local C = TK.GetComponent("7x.clock")
local H = __tk
local S = require("interfaces.7x.skin")
local Hud = require("interfaces.7x.hud")
local Screen = require("interfaces.screen")

local RECT = { 830, 736, 885, 751 }

-- g_hourFrameTable (0x0066DB04): TIME.EPF's frame for each two-hour period from midnight
local FRAMES = { 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }

--- TIME.EPF's frame for an hour (0-23), or nil for no hour yet.
function C.Frame(hour)
    if hour < 0 then return nil end
    return FRAMES[math.floor(hour / 2) % 12 + 1]
end

function C:OnEnable()
    local f = CreateFrame("Frame", "TK7xClock", UIParent)
    f:SetFrameStrata("LOW")
    f:SetFrameLevel(10) -- the frame layer, over the screen's backdrop
    f:SetSize(RECT[3] - RECT[1], RECT[4] - RECT[2])
    f:EnableMouse(true)
    -- the hour's tip on the right press. WIRE (s6-interface-7x-b round 6): HourPane::HandlePointerOrMouseEvent
    -- (0x004CEF30) shows it for type 4 only, so a right double press (type 5) shows none; the tip uses up the next press
    -- (Hud.HelpLine.Show), so a tip 4a does not show would take a press 4a sends on
    f:SetScript("OnMouseDown", function(_, button, double)
        if button ~= "RightButton" or double then return end
        local label = H:OriginalString(77) or "Current time"
        Hud.HelpLine.Show(f, string.format("%s : %02d", label, self.hour or -1), 5000)
    end)
    -- the hour as the logic has it, drawn when it changes (UpdateHour: only a changed hour repaints)
    f:SetScript("OnUpdate", function() self:Paint() end)
    f:Hide()
    self.frame = f
    self:Own(f)
    self.entry = Screen.Register(f, "7x.clock", "7.x Clock", function() return self:DB().enabled == true end)
end

--- The hour's picture, when the hour has changed.
function C:Paint()
    local f = self.frame
    local hour = H:GetGameHour()
    if hour == self.hour then return end
    self.hour = hour
    local frame = C.Frame(hour)
    if frame then
        f.art = S.Picture(f, f.art, "TIME.EPF", frame, "TIME.PAL", 0, 0, "ARTWORK")
    elseif f.art then
        f.art:Hide()
    end
end

function C:Layout() Screen.PlacePanel(self, 1024, 768, RECT[1], RECT[2]) end

function C:ApplySettings() self:Layout() end

Screen.Follow(C, "Layout")
