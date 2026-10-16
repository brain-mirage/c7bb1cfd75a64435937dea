-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md): 5.x's screen. NexusTK 5.33
-- draws on a 640 x 480 screen (MainMenuPane::InitializeMainUiGraph 0x00457530); ours is that screen scaled to fit the
-- window, centred, and while 5.x is the interface in use the sides it leaves are black (the letterbox, over the world
-- view). Its pieces are 5.33's panes there, each a panel with its own frame, Layout tab and edit-mode place (default:
-- 5.33's place on the scaled screen, followed as the window changes while the player has not moved it):
--   the backdrop   BackPane (0x00404B50): FRAME.EPF in NPAL5.PAL over the whole screen, under the world view;
--   the border     BuildAboveFrameBorder (0x004011D0): thirteen AboveFrame pieces of FRMPART.EPF in NPAL5.PAL, the
--                  corners and the top bar at (14, 12), (125, 12), (378, 12), five side pieces each at (14, y + 6)
--                  and (420, y) for y from 92 by 63;
--   the map name   MapNamePane (151, 0)-(284, 12): the map's name shortened to 133 pixels with "...", in white over
--                  the border's top bar, centred (MapNamePane::HandlePacketEvent 0x0045FC80; its paint as 4a's classic
--                  branch, whose fill of colour 0 is 0x0000, 5.33's transparent key in this keyed pane (0x45fb73, mode
--                  1): W:/5-3-client-source/documentation/interface/black-boxes.md; s6-ui-core round 86);
--   the clock      HourPane (14, 375)-(43, 387): TIME.EPF, a picture every two hours (HourPane::OnPaint 0x00442420,
--                  its table at 0x00550678), black while the hour is unknown; a right press shows the hour's help line.
-- The world view goes to 5.33's map view, (14, 12)-(422, 372): MapPane(17, 15) at (-10, -12)-(446, 396), its 24-pixel
-- cells one beyond each edge, so the 17 x 15 the server sends fill 408 x 360 (decision 2026-10-04-5x-world-in-the-map-view).
-- In the game only (the pre-game is ours). It draws only; nothing here is sent.

local C = TK.GetComponent("5x.screen")
local S = require("interfaces.5x.skin")
local Screen = require("interfaces.screen")
local Help = require("interfaces.5x.help") -- s6-interface-5x-b

local MAP_VIEW = { 14, 12, 422, 372 }

-- The border's pieces { frame, x, y } (BuildAboveFrameBorder: AboveFrame(frame, top, left) offsets the frame's own
-- rectangle, (0, 0) in every frame of 5.33's FRMPART.EPF, by (left, top)).
local BORDER = { { 0, 14, 12 }, { 1, 125, 12 }, { 2, 378, 12 } }
for y = 92, 406, 63 do
    BORDER[#BORDER + 1] = { 3, 14, y + 6 }
    BORDER[#BORDER + 1] = { 4, 420, y }
end

-- HourPane's frame of TIME.EPF for each two hours (word_550678: hour / 2 % 12 indexes it).
local HOUR_FRAMES = { 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }

-- The pieces: their settings' key, panel id (their place is "5x.<id>"), frame name, rectangle on the screen, and how
-- they draw (build once; update when what they show changes).
local PIECES = {
    { key = "backdrop", id = "backdrop", name = "TK5xBackdrop", label = "5.x Backdrop", rect = { 0, 0, 640, 480 },
      strata = "BACKGROUND", level = 0,
      build = function(f)
          -- what FRAME.EPF leaves undrawn (its map view, chat and prompt line) is the screen's black
          local black = f:CreateTexture(nil, "BACKGROUND")
          black:SetAllPoints(f)
          black:SetColorTexture(0, 0, 0, 1)
          S.Picture(f, nil, "FRAME.EPF", 0, "NPAL5.PAL", 0, 0)
      end },
    { key = "border", id = "border", name = "TK5xBorder", label = "5.x Border", rect = { 14, 12, 422, 371 },
      build = function(f)
          f.pieces = {}
          for i, p in ipairs(BORDER) do f.pieces[i] = S.Picture(f, nil, "FRMPART.EPF", p[1], "NPAL5.PAL", p[2] - 14, p[3] - 12) end
      end },
    { key = "mapName", id = "mapname", name = "TK5xMapName", label = "5.x Map Name", rect = { 151, 0, 284, 12 },
      build = function(f)
          f.text = S.Text(f:CreateFontString(nil, "ARTWORK"), S.WHITE)
          f.text:SetWordWrap(false)
          f.text:SetJustifyH("LEFT")
      end,
      update = function(f)
          local known, zone = __tk:GetLocation()
          local text = known and zone or ""
          if f.shown == text then return end
          f.shown = text
          -- the name fitted to 133 pixels (GrafPort::FitTextAndAppendSuffix), centred by font 0's advances, its line's
          -- glyphs ending at the pane's bottom (MoveTo(centre - width / 2, bottom), DrawWideText)
          local fitted = require("interfaces.5x.dialogs").X.Fit(text, 133)
          f.text:SetText(fitted)
          local w = S.TextWidth(fitted) or 0
          f.text:ClearAllPoints()
          f.text:SetPoint("TOPLEFT", f, "TOPLEFT", math.floor(133 / 2) - math.floor(w / 2), -1)
      end },
    { key = "clock", id = "clock", name = "TK5xClock", label = "5.x Clock", rect = { 14, 375, 43, 387 },
      build = function(f)
          f.back = f:CreateTexture(nil, "BACKGROUND")
          f.back:SetAllPoints(f)
          S.Fill(f.back, S.TEXT)
          -- s6-interface-5x-b: a right press shows the hour (HourPane_HandlePointerOrMouseEvent 0x00442350: "%s : %02d"
          -- with line 77, "Current time", the same in 7.5.2's string table; interfaces/5x/help.lua)
          Help.OnRightPress(f, function()
              local text = Help.String(77)
              return text and string.format("%s : %02d", text, math.max(0, __tk:GetGameTime() or 0))
          end)
      end,
      update = function(f)
          local hour = __tk:GetGameTime()
          if f.hour == hour then return end
          f.hour = hour
          local known = hour and hour >= 0
          f.back:SetShown(not known)
          if known then
              f.picture = S.Picture(f, f.picture, "TIME.EPF", HOUR_FRAMES[math.floor(hour / 2) % 12 + 1], nil, 0, 0)
          elseif f.picture then
              f.picture:Hide()
          end
      end },
}

function C:OnEnable()
    self.frames, self.entries = {}, {}
    for _, piece in ipairs(PIECES) do
        local f = CreateFrame("Frame", piece.name, UIParent)
        f:SetFrameStrata(piece.strata or "LOW")
        if piece.level then f:SetFrameLevel(piece.level) end
        f:SetSize(piece.rect[3] - piece.rect[1], piece.rect[4] - piece.rect[2])
        piece.build(f)
        f:Hide()
        self:Own(f)
        self.frames[piece.key] = f
        local key = piece.key
        self.entries[key] = Screen.Register(f, "5x." .. piece.id, piece.label, function() return self:DB()[key].enabled == true end)
    end
    self.bars = Screen.MakeBars("TK5xLetterbox")
    -- s6-interface-5x (round 14; Astra's review of round 13, P2): the shared screen code makes them on UIParent, which
    -- makes them no panel's until owned, so they go with the screen when it is unloaded
    for _, bar in ipairs(self.bars) do self:Own(bar) end
    -- the map name and the clock follow the session (what they show changes rarely; updated only when it does)
    local ticker = CreateFrame("Frame", nil, UIParent)
    ticker:SetScript("OnUpdate", function()
        for _, piece in ipairs(PIECES) do
            local f = self.frames[piece.key]
            if piece.update and f:IsShown() then piece.update(f) end
        end
    end)
end

--- Places the pieces (at 5.33's places unless moved, at the screen's scale times their own), the letterbox and (while it
--- keeps to it) the world view at the map view, for the window now.
function C:Layout()
    if not self.frames then return end
    local db = self:DB()
    local inWorld = TK.GameState:InWorld()
    for _, piece in ipairs(PIECES) do
        local d = db[piece.key]
        Screen.Place(self.entries[piece.key], S.WIDTH, S.HEIGHT, piece.rect[1], piece.rect[2], d.scale)
        self.frames[piece.key]:SetShown(inWorld and d.enabled == true)
    end
    TK.EditMode:UpdateMovers()
    Screen.Bars(self.bars, inWorld and TK.Interfaces.active == "5x", S.WIDTH, S.HEIGHT)
    if db.mapPane then Screen.PlaceWorldView(db, S.WIDTH, S.HEIGHT, MAP_VIEW) end
end

function C:ApplySettings() self:Layout() end

function C:OnSettingChanged(_, key)
    -- turned on again on its page: the world view goes back to the map view
    if key == "mapPane" then self:DB().placed = nil end
    self:Layout()
end

Screen.Follow(C, "Layout")
