-- s6-interface-7x-b: 7.x's map name, the original's MapNamePane (ui/MapNamePane.cpp) at (316, 0)-(509, 24) on the 7.x
-- screen, in the frame layer over the map view (MainMenuPane::InitializeMainUiGraph). Its plate is MAPNAME.EPF frame 0 in
-- FRMPART.PAL; the map's name from the server's last 0x15 (the location the logic keeps: __tk:GetLocation), cut to 173
-- pixels with "..." (HandlePacketEvent 0x005034A0's FitTextAndAppendSuffix), centred on the plate in 0x80, drawn twice a
-- pixel apart (bold), its pen 5 below the plate's middle (OnPaint 0x00503350). Its place follows the scaled screen until
-- the player moves it (edit mode, its Layout tab).
-- s6-ui-core (round 85): the XML twin's scripts; its frame, place, plate and text are main.xml's (core/xml.md).
--
-- Wire: nothing is sent. It only reads 0x15, which goes on to the map (HandlePacketEvent returns false). It takes no
-- press: 4a's pane keeps Pane::HandlePointerOrMouseEvent, which declines it, so a press on the plate goes on to the map
-- view under it (a step, a target, a look). This frame is therefore never mouse-enabled (main.xml); enabling it would turn
-- those presses into no map press, which the server would see.

local C = TK.GetComponent("7x.mapname")
local H = __tk
local S = require("interfaces.7x.skin")
local Screen = require("interfaces.screen")
-- 7.x's drawing helpers (X.Bold; s6-interface-7x-b round 8, the separation's step 5: interfaces/7x/draw.lua, the
-- dialogs look's file's before)
local X = require("interfaces.7x.draw")
local E = require("interfaces.7x.elements")

local L = TK.Xml.Data("main.xml")

-- the scripts main.xml names
local scripts = {}

function scripts.Update() C:Paint() end

function C:OnEnable()
    local f = TK.Xml.Load("main.xml", { scripts = scripts, elements = E }).frame
    self.frame = f
    self:Own(f)
    self.entry = Screen.Register(f, "7x.mapname", "7.x Map Name", function() return self:DB().enabled == true end)
end

--- The name, when the map's has changed: cut to 173 pixels, centred (x = the middle - width / 2), its pen at the plate's
--- middle + 5 (12 + 5 = 17).
function C:Paint()
    local f = self.frame
    local known, zone = H:GetLocation()
    local name = known and zone or ""
    if name == self.shown then return end
    self.shown = name
    local n = L.NAME
    local text = S.Cut(name, n.fit)
    local width = S.TextWidth(text) or 0
    X.Bold(f, f.name, math.floor(f:GetWidth() / 2) - math.floor(width / 2), n.baseline, S[n.colour])
    f.name:SetText(text)
end

function C:Layout() Screen.PlacePanel(self, 1024, 768, L.PLACE[1], L.PLACE[2]) end

function C:ApplySettings() self:Layout() end

Screen.Follow(C, "Layout")
