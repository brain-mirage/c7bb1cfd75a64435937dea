-- s6-modular-g (interfaces, phase 5, round 13): 7.x's menu button, the original's MENU (MenuVarietyPane, constructor
-- 0x005BC970) at (744, 727)-(805, 751) on the 7.x screen, in the frame layer: MENUVAR.EPF in MENUVAR.PAL, frame 0 while its
-- popup is closed and frame 2 while it is open (OnPaint 0x005BC800; frame 1, a hover picture, is never drawn). Its place
-- follows the scaled screen (interfaces/screen.lua's Screen.Place) until the player moves it (edit mode, its Layout tab).
--
-- Wire: MenuVarietyPane::HandlePointerOrMouseEvent (0x005BC690) opens the popup (MenuVarietySelectPane) on the left
-- press, or closes the open one. The press goes to the dialogs' model in its own event, as the micro menu's Menu button's
-- does (TK.Dialogs.MenuPress, s6-play-modes round 8; a press while the popup is open is the model's close, one record a
-- press), so the popup, its rows and what they open or send are the model's. Changing which press opens it, or when,
-- changes what the client does with it.

local C = TK.GetComponent("7x.menu")
local Screen = require("interfaces.screen")
local S = require("interfaces.7x.skin")

-- the button on the 7.x screen (MenuVarietyPane's rectangle)
local RECT = { 744, 727, 805, 751 }

function C:OnEnable()
    local f = CreateFrame("Button", "TK7xMenuButton", UIParent)
    f:SetFrameStrata("LOW")
    f:SetFrameLevel(10) -- over the screen's border, as the frame layer's panes are over its backdrop
    f:SetSize(RECT[3] - RECT[1], RECT[4] - RECT[2])
    f.art = f:CreateTexture(nil, "ARTWORK")
    f:EnableMouse(true)
    f:SetScript("OnMouseDown", function(_, button)
        if TK.Dialogs then TK.Dialogs.MenuPress(button) end
    end)
    f:Hide()
    self.frame = f
    self:Own(f)
    self.entry = Screen.Register(f, "7x.menu", "7.x Menu Button", function() return self:DB().enabled == true end)
    self:SetOpen(false)
end

--- The button's picture: MENUVAR.EPF frame 2 while the popup is open, frame 0 otherwise (the 7.x Menu popup's look tells
--- it: interfaces/7x/dialogs/panes.lua), at the button's top left (S.Picture; none without the picture: the press is
--- the button's either way).
function C:SetOpen(open)
    local f = self.frame
    if not f then return end
    S.Picture(f, f.art, "MENUVAR.EPF", open and 2 or 0, "MENUVAR.PAL", 0, 0)
end

--- At the original's place on the scaled screen (unless moved), at the screen's scale times its own; in the game only.
function C:Layout() Screen.PlacePanel(self, 1024, 768, RECT[1], RECT[2]) end

function C:ApplySettings() self:Layout() end

Screen.Follow(C, "Layout")
