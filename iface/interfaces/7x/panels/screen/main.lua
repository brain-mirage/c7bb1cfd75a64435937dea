-- s6-modular-g (interfaces, phase 3; docs/development/interfaces.md, section 3 "7.x"): 7.x's screen. The
-- original draws on a 1024 x 768 screen (Source-5's systems/entering-the-game-world.md, "The EPF layout"); ours is that
-- screen scaled to fit the window, centred, and while 7.x is the interface in use the sides it leaves are black (the
-- letterbox, over the world view). Its decoration pieces are drawn from the packs, each a panel of its own with its own
-- frame (Astra's review of round 9: each has a Layout tab and an edit-mode place): the backdrop (the BackPane, base
-- layer) under the world view; the border, the tab header, the divider and the chat backdrop (frame layer) over it. A
-- piece's default place is the original's on the scaled screen, followed as the window changes while the player has not
-- moved it (edit mode's default, given again at each layout); its own scale multiplies the screen's. In the game only:
-- the pre-game is ours in every interface. It draws only; nothing here is sent.
-- s6-ui-core (round 85): the XML twin's scripts; the pieces, their pictures and the screen's places are main.xml's
-- (core/xml.md).

local C = TK.GetComponent("7x.screen")
local H = __tk
local Screen = require("interfaces.screen")

local L = TK.Xml.Data("main.xml")
local SCREEN_W, SCREEN_H = L.SCREEN[1], L.SCREEN[2]
local MAP_VIEW = L.MAP_VIEW

-- the scripts main.xml names
local scripts = {}

--- A piece's pictures at their places on its frame, its size their rectangle (or its own); the rectangle on the screen
--- (left, top) is kept as f.at, its textures as f.textures. Hidden until the layout shows it; then its panel's, with its
--- edit-mode place.
function scripts.Build(f)
    local piece = f.piece
    local textures, rect = {}, piece.rect
    if not rect then
        -- the pictures' rectangle: each at its frame's place plus where its crop starts (TK.Art.Origin)
        local placed = {}
        for i, p in ipairs(f.pictures) do
            local key, w, h = TK.Art.Image(p.file, p.frame, p.palette)
            local ox, oy = 0, 0
            if key then ox, oy = TK.Art.Origin(key) end
            placed[i] = { key = key, x = p.x + ox, y = p.y + oy, w = w or 1, h = h or 1 }
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
        local ok, r, g, b = H:GetPaletteColour(L.CHAT.palette, L.CHAT.index)
        if ok then t:SetColorTexture(r, g, b, piece.alpha) else t:SetColorTexture(0, 0, 0, piece.alpha) end
        t:SetAllPoints(f)
        textures[1] = t
    end
    f:SetSize(rect[3] - rect[1], rect[4] - rect[2])
    f.at, f.textures = rect, textures
    f:Hide()
    C:Own(f)
    local key = piece.setting
    -- edit mode moves it while it is on; its default (the original's place) is given at each layout
    C.entries[key] = TK.EditMode:Register(f, "7x." .. piece.id, piece.label, { "TOPLEFT", "TOPLEFT", 0, 0 },
        "7x." .. piece.id, function() return C:DB()[key].enabled == true end)
end

function C:OnEnable()
    self.frames, self.pieces, self.entries = {}, {}, {}
    self.pieceFrames = TK.Xml.Load("main.xml", { scripts = scripts }).roots
    for _, f in ipairs(self.pieceFrames) do
        self.frames[f.piece.setting], self.pieces[f.piece.setting] = f, f.textures
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
    for _, f in ipairs(self.pieceFrames) do
        local key = f.piece.setting
        local d = db[key]
        Screen.Place(self.entries[key], SCREEN_W, SCREEN_H, f.at[1], f.at[2], d.scale)
        f:SetShown(inWorld and d.enabled == true)
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
    t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(top - L.DIVIDER.top))
end

--- s6-interface-7x-b: the chat backdrop for the chat log's rows, mode and switch (main.xml's CHAT: it grows upwards from
--- its piece's bottom; nothing in mode 0 or with the chat off). Drawing only.
function C:ShowChatBackdrop(rows, mode, on)
    local f = self.frames and self.frames.chatBackdrop
    local t = self.pieces and self.pieces.chatBackdrop and self.pieces.chatBackdrop[1]
    if not (f and t) then return end
    local c = L.CHAT
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    t:SetHeight(c.bottom - (c.top - c.row * rows))
    local ok, r, g, b = H:GetPaletteColour(c.palette, c.index)
    if not ok then r, g, b = 0, 0, 0 end
    t:SetColorTexture(r, g, b, mode == 2 and c.mode2 / c.parts or c.mode1 / c.parts)
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
        L.MAP_CELLS[1], L.MAP_CELLS[2], self:DB())
end

--- The tab header for the side panel's active tab index (-1 none), as SwitchActiveTab rebuilds AboveFrame's header
--- (RecreateDynamicAboveFrame 0x004615D0: TABS.EPF entry 0 with no tab, 1 for the self look or another player's, the
--- tab's own index for the others), at main.xml's TAB_HEADER.
function C:ShowTabHeader(index)
    local f, textures = self.frames and self.frames.tabHeader, self.pieces and self.pieces.tabHeader
    if not (f and textures) then return end
    local a = L.TAB_HEADER
    local entry = index < 0 and 0 or (index <= 1 and 1 or index)
    local key, w, h = TK.Art.Image(a.file, entry, a.palette)
    if not key then return end
    local ox, oy = TK.Art.Origin(key)
    local at = f.at
    local t = textures[1]
    t:SetTexture(key)
    t:SetSize(w, h)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", f, "TOPLEFT", a.x + ox - at[1], -(a.y + oy - at[2]))
end

TK.On("TK_SIDE_PANEL_TAB", function(_, index) C:ShowTabHeader(index) end)
-- Q147 (the owner, 2026-10-15: highlight the open tab after an interface switch): a 7.x screen started by the switch
-- shows the side panel's open tab in its strip rather than the start's unhighlighted one (only the switch fires
-- TK_INTERFACE_CHANGED, so the start stays unhighlighted). Drawing only (AboveFrame's header, 4a 0x004615D0); nothing is
-- sent. Round 115: here, no longer in core/interfaces.lua, which named this component (the separation guard's G2).
TK.On("TK_INTERFACE_CHANGED", function() C:ShowTabHeader(TK.Game.SidePanel.Active()) end)

function C:ApplySettings() self:Layout() end

function C:OnSettingChanged(_, key)
    -- turned on again on its page: the world view goes back to the map pane
    if key == "mapPane" then self:DB().placed = nil end
    self:Layout()
end

Screen.Follow(C, "Layout")
