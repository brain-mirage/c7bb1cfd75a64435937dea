-- s6-modular-g (interfaces, phase 3; docs/development/interfaces.md, section 3 "7.x"): 7.x's screen. The
-- original draws on a 1024 x 768 screen (Source-5's systems/entering-the-game-world.md, "The EPF layout"); ours is that
-- screen scaled to fit the window, centred, and while 7.x is the interface in use the sides it leaves are black (the
-- letterbox, over the world view). Its decoration pieces are drawn from the packs, each a panel of its own with its own
-- frame (Astra's review of round 9: each has a Layout tab and an edit-mode place): the backdrop (the BackPane, base
-- layer) under the world view; the border, the tab header, the divider and the chat backdrop (frame layer) over it. A
-- piece's default place is the original's on the scaled screen, followed as the window changes while the player has not
-- moved it (edit mode's default, given again at each layout); its own scale multiplies the screen's. In the game only:
-- the pre-game is ours in every interface. It draws only; nothing here is sent.

local C = TK.GetComponent("7x.screen")
local H = __tk
local Screen = require("interfaces.screen")

local SCREEN_W, SCREEN_H = 1024, 768

-- The pieces: their settings' key, their panel id (their place is "7x.<id>"), their frame's name, and their pictures
-- { file, frame, palette, x, y } on the screen (the EPF layout's rows 1 and 8; the divider at its default height,
-- Config::m_systemMessageHeight 70, in the messages panel at (832, 376): NewSystemMessageModifyHeightPane). A piece's
-- frame is its pictures' rectangle on the screen.
local PIECES = {
    { key = "backdrop", id = "backdrop", name = "TK7xBackdrop", label = "7.x Backdrop", strata = "BACKGROUND", level = 0,
      pictures = { { "FRAME.EPF", 0, "FRAME.PAL", 0, 0 } } },
    { key = "border", id = "border", name = "TK7xFrame", label = "7.x Border",
      pictures = { { "FRMPART.EPF", 0, "FRMPART.PAL", 0, 0 }, { "FRMPART.EPF", 1, "FRMPART.PAL", 0, 9 },
                   { "FRMPART.EPF", 2, "FRMPART.PAL", 808, 9 } } },
    -- the header of the side panel's active tab; none is active when the game screen is built (m_activeChildIndex -1:
    -- AboveFrame's index -1 + 5 = 4, entry 0 of TABS.EPF); it follows the side panel's tab (C:ShowTabHeader)
    { key = "tabHeader", id = "tabheader", name = "TK7xTabHeader", label = "7.x Tab Header", pictures = { { "TABS.EPF", 0, "TABS.PAL", 808, 79 } } },
    { key = "divider", id = "divider", name = "TK7xDivider", label = "7.x Messages Divider", pictures = { { "SYSBAR.EPF", 0, "INVENBUT.PAL", 835, 446 } } },
    -- the chat backdrop (ChattingBackPane, mode 1): palette index 128 of BARAM.PAL (black) over the scene, which keeps 70 %
    { key = "chatBackdrop", id = "chatbackdrop", name = "TK7xChatBackdrop", label = "7.x Chat Backdrop", rect = { 9, 596, 816, 720 } },
}

-- The original's map view: its pane is (-48, -48)-(864, 768), 17 x 15 tiles and one beyond each edge (MapPane(17, 15)),
-- but it draws only through its clip, (48, 48)-(864, 768) in the pane (MapPane::AddToLayer), so (0, 0)-(816, 720) on the
-- screen: the backdrop shows beside and below it (the capture against the original 7.5.2, round 9).
local MAP_VIEW = { 0, 0, 816, 720 }

--- A piece's frame and its pictures at their places on it; its rectangle on the screen (left, top) is kept as piece.at.
local function build(piece)
    local f = CreateFrame("Frame", piece.name, UIParent)
    f:SetFrameStrata(piece.strata or "LOW")
    if piece.level then f:SetFrameLevel(piece.level) end
    local textures, rect = {}, piece.rect
    if not rect then
        -- the pictures' rectangle: each at its frame's place plus where its crop starts (TK.Art.Origin)
        local placed = {}
        for i, p in ipairs(piece.pictures) do
            local key, w, h = TK.Art.Image(p[1], p[2], p[3])
            local ox, oy = 0, 0
            if key then ox, oy = TK.Art.Origin(key) end
            placed[i] = { key = key, x = p[4] + ox, y = p[5] + oy, w = w or 1, h = h or 1 }
            local r = { placed[i].x, placed[i].y, placed[i].x + placed[i].w, placed[i].y + placed[i].h }
            rect = rect and { math.min(rect[1], r[1]), math.min(rect[2], r[2]), math.max(rect[3], r[3]), math.max(rect[4], r[4]) } or r
        end
        for i, p in ipairs(placed) do
            local t = f:CreateTexture(nil, "ARTWORK")
            if p.key then t:SetTexture(p.key) else t:SetColorTexture(0, 0, 0, 0) end
            t:SetSize(p.w, p.h)
            t:SetPoint("TOPLEFT", f, "TOPLEFT", p.x - rect[1], -(p.y - rect[2]))
            textures[i] = t
        end
    else
        local t = f:CreateTexture(nil, "BACKGROUND")
        local ok, r, g, b = H:GetPaletteColour("BARAM.PAL", 128)
        if ok then t:SetColorTexture(r, g, b, 0.3) else t:SetColorTexture(0, 0, 0, 0.3) end
        t:SetAllPoints(f)
        textures[1] = t
    end
    f:SetSize(rect[3] - rect[1], rect[4] - rect[2])
    piece.at = rect
    f:Hide()
    return f, textures
end

function C:OnEnable()
    self.frames, self.pieces, self.entries = {}, {}, {}
    for _, piece in ipairs(PIECES) do
        local f, textures = build(piece)
        self.frames[piece.key], self.pieces[piece.key] = f, textures
        self:Own(f)
        local key = piece.key
        -- edit mode moves it while it is on; its default (the original's place) is given at each layout
        self.entries[key] = TK.EditMode:Register(f, "7x." .. piece.id, piece.label, { "TOPLEFT", "TOPLEFT", 0, 0 },
            "7x." .. piece.id, function() return self:DB()[key].enabled == true end)
    end
    self.bars = Screen.MakeBars("TK7xLetterbox")
    -- s6-interface-5x (round 14; Astra's review of round 13, P2): the shared screen code makes them on UIParent, which
    -- makes them no panel's until owned, so they go with the screen when it is unloaded
    for _, bar in ipairs(self.bars) do self:Own(bar) end
end

--- Places the screen's pieces (at the original's places unless moved, at the screen's scale times their own), its
--- letterbox and (while it keeps to it) the world view at the map view, for the window now.
function C:Layout()
    if not self.frames then return end
    local db = self:DB()
    local inWorld = TK.GameState:InWorld()
    for _, piece in ipairs(PIECES) do
        local d = db[piece.key]
        Screen.Place(self.entries[piece.key], SCREEN_W, SCREEN_H, piece.at[1], piece.at[2], d.scale)
        self.frames[piece.key]:SetShown(inWorld and d.enabled == true)
    end
    TK.EditMode:UpdateMovers()
    Screen.Bars(self.bars, inWorld and TK.Interfaces.active == "7x", SCREEN_W, SCREEN_H)
    if db.mapPane then
        -- the screen's scale, left and bottom in the window (interfaces/screen.lua's fit; s6-interface-5x round 15, the
        -- separation's step 9: C.Letterbox, its forwarder, went)
        local h = GetScreenHeight()
        local s, l, top = Screen.Fit(SCREEN_W, SCREEN_H, GetScreenWidth(), h)
        self:PlaceWorldView(s, l, h - top - SCREEN_H * s, h)
    end
end

--- s6-interface-7x-b: the messages divider at its pane's divider top H (the messages panel's drag and saved height:
--- NewSystemMessageModifyHeightPane at (3, H) of the page at (832, 376), so 376 + H on the screen; its piece's place is
--- H 70's, 446), as the side panel's tab follows TABS (ShowTabHeader). Drawing only.
function C:ShowDivider(top)
    local f, t = self.frames and self.frames.divider, self.pieces and self.pieces.divider and self.pieces.divider[1]
    if not (f and t) then return end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(top - 70))
end

--- s6-interface-7x-b: the chat backdrop for the chat log's rows, mode and switch (ChattingBackPane::ResizeForLineCount
--- 0x004806D0: (9, 700 - 13 rows)-(816, 720), so it grows upwards from its piece's bottom; OnPaint 0x00480740: BARAM.PAL's
--- 128 over the scene, which keeps 22 of 32 parts in mode 1 and 10 in mode 2; nothing in mode 0 or with the chat off).
--- Drawing only.
function C:ShowChatBackdrop(rows, mode, on)
    local f = self.frames and self.frames.chatBackdrop
    local t = self.pieces and self.pieces.chatBackdrop and self.pieces.chatBackdrop[1]
    if not (f and t) then return end
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    t:SetHeight(720 - (700 - 13 * rows))
    local ok, r, g, b = H:GetPaletteColour("BARAM.PAL", 128)
    if not ok then r, g, b = 0, 0, 0 end
    t:SetColorTexture(r, g, b, mode == 2 and 22 / 32 or 10 / 32)
    t:SetShown(on and (mode == 1 or mode == 2))
end

--- The world view at the original's map view on the screen, as 7.x's first profile has it (the pane's 19 x 17 cells, so
--- the frame shows the middle as the original's clip does, and a step scrolls the band in), again whenever the window
--- changes; once the player has moved or resized it, it stays theirs and the screen's switch turns off. s6-input (round
--- 49, separation step 4b): the shared view places itself (TK.WorldView:PlaceAt).
function C:PlaceWorldView(s, l, b, h)
    if not TK.WorldView then return end
    local top = h - (b + SCREEN_H * s) + MAP_VIEW[2] * s
    TK.WorldView:PlaceAt({ l + MAP_VIEW[1] * s, top, (MAP_VIEW[3] - MAP_VIEW[1]) * s, (MAP_VIEW[4] - MAP_VIEW[2]) * s },
        19, 17, self:DB())
end

--- The tab header for the side panel's active tab index (-1 none), as SwitchActiveTab rebuilds AboveFrame's header
--- (RecreateDynamicAboveFrame 0x004615D0: TABS.EPF entry 0 with no tab, 1 for the self look or another player's, the
--- tab's own index for the others), at (808, 79).
function C:ShowTabHeader(index)
    local f, textures = self.frames and self.frames.tabHeader, self.pieces and self.pieces.tabHeader
    if not (f and textures) then return end
    local entry = index < 0 and 0 or (index <= 1 and 1 or index)
    local key, w, h = TK.Art.Image("TABS.EPF", entry, "TABS.PAL")
    if not key then return end
    local ox, oy = TK.Art.Origin(key)
    local at, t
    for _, piece in ipairs(PIECES) do if piece.key == "tabHeader" then at = piece.at end end
    t = textures[1]
    t:SetTexture(key)
    t:SetSize(w, h)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", f, "TOPLEFT", 808 + ox - at[1], -(79 + oy - at[2]))
end

TK.On("TK_SIDE_PANEL_TAB", function(_, index) C:ShowTabHeader(index) end)

function C:ApplySettings() self:Layout() end

function C:OnSettingChanged(_, key)
    -- turned on again on its page: the world view goes back to the map pane
    if key == "mapPane" then self:DB().placed = nil end
    self:Layout()
end

Screen.Follow(C, "Layout")
