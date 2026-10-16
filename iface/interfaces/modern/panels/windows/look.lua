-- The look at another player (S 0x34; head notes 39 and 42): the original shows it in the side panel's tab 1
-- (UserLookPane) when the server sends it, with four views paged by arrows. Here it is a window that opens on every
-- look, on its first view as the original's does (s6-ui-character, coverage rows G-10 to G-12, H-17):
--   - the player's name (gold when the packet highlights it), the header and the three identity lines, and the figure
--     as the original's look pane draws it (s6-characters' "look");
--   - Trade and Group, the original's action buttons 0 and 1: 4A 00 with the player's id, and 2E with the name. Their
--     rule (TK-Core LookRules) sends them, and refuses both while the look's gate byte is 0xFF, when the original shows
--     no buttons (so do we); each shows its state byte, which picks the original's button picture. The page acts on the
--     left button down (UserLookPane::HandlePointerOrMouseEvent's type 1), so do they: the release sends nothing;
--   - the views as tabs: Info (the more-info text), Equipment (the fourteen items where the original's view 1 draws
--     them), Profile (the portrait and the profile text) and Legend.
-- Opening and closing it send nothing; it closes with its button or Esc.

local H = __tk
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin

local Look = {}
TK.Look = Look

-- The figure's background (0xRRGGBB), the box it is painted onto, as the character window's.
local BG = { 0x1C, 0x1C, 0x21 }

local WIDTH, HEIGHT = 300, 524
local VIEWS = { { id = "info", label = "Info" }, { id = "equipment", label = "Equipment" },
    { id = "profile", label = "Profile" }, { id = "legend", label = "Legend" } }

-- UserLookPane::OnPaint, view 1: each record's place in the 3 x 5 grid (column, row), in the packet's order (weapon,
-- armour, shield, helm, the two accessories, the two sub-accessories, face, crown, mantle, necklace, boots, coat).
local GRID = { { 0, 1 }, { 1, 1 }, { 2, 1 }, { 1, 0 }, { 2, 2 }, { 0, 2 }, { 0, 3 }, { 2, 3 }, { 0, 0 }, { 2, 0 },
    { 1, 2 }, { 0, 4 }, { 1, 4 }, { 1, 3 } }

local frame

local function stateText(v)
    if v == 0xFF then return "" elseif v ~= 0 then return ": On" end
    return ": Off"
end

--- A Trade or Group button: the game layer's look action (TK.Game.Look.ActionButton: on the left press).
local function actionButton(f, label, kind, tip)
    local b = W.Button(f, label, 124, 22)
    TK.Game.Look.ActionButton(b, kind)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(label, 1, 1, 1)
        GameTooltip:AddLine(tip, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function itemSlot(parent, i)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(34, 34)
    local cell = GRID[i]
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", 54 + cell[1] * 58, -6 - cell[2] * 38)
    s.icon = select(2, W.SlotArt(s)) -- s6-ui-core (round 62): the shared slot's picture, an item's edge
    s:EnableMouse(true)
    s:SetScript("OnEnter", function(self)
        local _, slotName, _, name = H:GetLookItem(i)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(name ~= "" and name or slotName, 1, 1, 1)
        if name ~= "" then GameTooltip:AddLine(slotName, 0.7, 0.7, 0.7) end
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return s
end

local function build()
    local f = W.Panel(UIParent, "TKLookWindow")
    TK.GetComponent("windows"):Own(f) -- (as the character window: made by the shared widgets, it goes with the windows)
    f:SetFrameStrata("DIALOG")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 260, 40)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f.name = W.Label(f, "", 16, W.white)
    f.name:SetPoint("TOP", f, "TOP", 0, -12)
    f.header = W.Label(f, "", 12, W.gold)
    f.header:SetPoint("TOP", f.name, "BOTTOM", 0, -4)
    f.box = CreateFrame("Frame", nil, f)
    f.box:SetSize(120, 190)
    f.box:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -54)
    f.box:SetBackdrop({ bg = { BG[1] / 255, BG[2] / 255, BG[3] / 255, 1 }, edge = false, bgFile = "tk:white" })
    f.figure = f.box:CreateTexture(nil, "ARTWORK")
    f.figure:SetPoint("BOTTOM", f.box, "BOTTOM", 0, 8)
    f.lines = W.Label(f, "", 11, { 0.85, 0.85, 0.85 }, "LEFT")
    f.lines:SetWordWrap(true)
    f.lines:SetWidth(WIDTH - 156)
    f.lines:SetPoint("TOPLEFT", f.box, "TOPRIGHT", 12, -2)
    -- The original's action buttons 0 (Trade) and 1 (Group).
    f.trade = actionButton(f, "Trade", "look:trade", "Asks this player to trade (4A 00 and the player's id).")
    f.trade:SetPoint("BOTTOMLEFT", f.box, "BOTTOMRIGHT", 12, 30)
    f.group = actionButton(f, "Group", "look:group", "Invites this player to your group (2E and the name).")
    f.group:SetPoint("TOPLEFT", f.trade, "BOTTOMLEFT", 0, -6)
    -- Named for the gate's driver (s6-gate round 37, H-17): gate mode logs a named control's place while it shows
    -- (core/gatecontrols.lua), so the gate can click these as it clicks the original's look page. Names only.
    _G.TKLookTrade, _G.TKLookGroup = f.trade, f.group

    -- The four views, as tabs.
    f.tabs, f.views = {}, {}
    for i, v in ipairs(VIEWS) do
        local b = W.Tab(f, v.label, 66, 20, function() Look:ShowView(v.id) end) -- s6-ui-core (round 61): the shared tab
        b:SetPoint("TOPLEFT", f.box, "BOTTOMLEFT", (i - 1) * 70, -10)
        f.tabs[v.id] = b
        local view = W.Panel(f, nil, true)
        view:SetPoint("TOPLEFT", f.box, "BOTTOMLEFT", 0, -36)
        view:SetSize(WIDTH - 24, 200)
        view:Hide()
        f.views[v.id] = view
    end
    f.moreInfo = W.Label(f.views.info, "", 12, W.white, "LEFT")
    f.moreInfo:SetWordWrap(true)
    f.moreInfo:SetWidth(WIDTH - 44)
    f.moreInfo:SetPoint("TOPLEFT", f.views.info, "TOPLEFT", 10, -10)
    f.slots = {}
    for i = 1, #GRID do f.slots[i] = itemSlot(f.views.equipment, i) end
    -- View 2: the portrait (48 x 56, shown twice its size) or the original's FACE.EPF without one, and the profile.
    f.portrait = f.views.profile:CreateTexture(nil, "ARTWORK")
    f.portrait:SetSize(96, 112)
    f.portrait:SetPoint("TOPLEFT", f.views.profile, "TOPLEFT", 10, -10)
    f.profile = W.Label(f.views.profile, "", 12, W.white, "LEFT")
    f.profile:SetWordWrap(true)
    f.profile:SetWidth(WIDTH - 150)
    f.profile:SetPoint("TOPLEFT", f.portrait, "TOPRIGHT", 10, 0)
    f.legend = W.Character.LegendList(f.views.legend, WIDTH - 36, 188)
    f.legend.sf:SetPoint("TOPLEFT", f.views.legend, "TOPLEFT", 4, -6)

    f.close = W.Button(f, "Close", 90, 22, "red", function() f:Hide() end)
    f.close:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    TK.Escape:AddWindow(f, function() f:Hide() end)
    f:Hide()
    return f
end

--- The look's figure, scaled by whole steps to its box; nothing while the drawing has none.
local function showFigure(f)
    local key, w, h = H:GetFigureOn("look", 0, BG[1] * 65536 + BG[2] * 256 + BG[3])
    if key == f.figureKey then return end
    f.figureKey = key
    f.figure:SetShown(key ~= "")
    if key == "" then return end
    local scale = math.max(1, math.min(3, math.floor(math.min(170 / h, 110 / w))))
    f.figure:SetTexture(key)
    f.figure:SetSize(w * scale, h * scale)
end

--- Shows one of the views (the tabs).
function Look:ShowView(id)
    if not frame then return end
    for vid, view in pairs(frame.views) do
        view:SetShown(vid == id)
        frame.tabs[vid]:SetSelected(vid == id)
    end
    frame.view = id
end

--- PgUp and PgDn (K-098): UserLookPane::HandleKeyOrTextEvent's 0x93 and 0x94 step the views back and forth, as its
--- arrows do (more info, equipment, profile, legend), stopping at either end.
function Look:Page(delta)
    if not frame then return end
    local at = 1
    for i, v in ipairs(VIEWS) do
        if v.id == frame.view then at = i end
    end
    self:ShowView(VIEWS[math.max(1, math.min(#VIEWS, at + delta))].id)
end

--- Opens the window on the last look, on its first view (UserLookPane::OnActivate ends in ShowMoreInfoView): the views'
--- window for the look (TK.Game.Views, below), shown when no interface's page takes it. Showing sends nothing.
local function showWindow()
    if not frame then
        frame = build()
        -- The figure is looked at again while the window shows (its picture follows the drawing's state), every 0.2 s as
        -- the look driver did before round 12 (a new look is the game layer's: TK.Game.Views' driver opens the view).
        frame:SetScript("OnUpdate", TK.Util.Throttled(0.2, function() showFigure(frame) end))
    end
    local _, name, header, line1, line2, line3 = H:GetLook()
    local _, moreInfo, profile, groupState, tradeState, highlighted, portrait = H:GetLookDetail()
    frame.name:SetText(name)
    W.Color(frame.name, highlighted and W.gold or W.white)
    frame.header:SetText(header)
    local lines = {}
    for _, l in ipairs({ line1, line2, line3 }) do
        if l ~= "" then lines[#lines + 1] = l end
    end
    frame.lines:SetText(table.concat(lines, "\n"))
    -- The gate byte 0xFF: no buttons, and their rule refuses them.
    frame.trade:SetShown(groupState ~= 0xFF)
    frame.group:SetShown(groupState ~= 0xFF)
    frame.trade:SetText("Trade" .. stateText(tradeState))
    frame.group:SetText("Group" .. stateText(groupState))
    frame.moreInfo:SetText(moreInfo)
    for i, s in ipairs(frame.slots) do
        local _, _, iconId = H:GetLookItem(i)
        local art, w, h = TK.Art.Icon(iconId)
        if art then
            TK.Art.Place(s.icon, s, art, w, h, 34)
            s.icon:Show()
        else
            s.icon:Hide()
        end
    end
    if portrait ~= "" then
        frame.portrait:SetTexture(portrait)
    else
        frame.portrait:SetTexture(TK.Art.Image("FACE.EPF", H:GetLookFaceFrame(), "PFLOOK.PAL") or "emoji:1f9cd")
    end
    frame.profile:SetText(profile)
    frame.legend:Fill(H:GetNumLookLegend(), function(i)
        local _, text, symbol, colour = H:GetLookLegend(i)
        return text, symbol, colour
    end, "No marks.")
    frame.figureKey = nil
    showFigure(frame)
    Look:ShowView("info")
    frame:Show()
    TK.FitToScreen(frame, 10)
end

function Look:IsShown() return frame ~= nil and frame:IsShown() end

-- s6-interface-5x (round 12, step 1): the window of the game layer's look view, which a new look (0x34) opens through
-- TK.Game.Views when no interface's page (5.x's look page) takes it. PgUp and PgDn page it first (pageOrder).
TK.Game.Views.SetWindow("look", {
    panel = { component = "windows", node = "look", switch = "enabled" }, -- its switch (Modern's panel; step 1)
    pageOrder = 1,
    Open = showWindow,
    Close = function() if frame then frame:Hide() end end,
    IsOpen = function() return Look:IsShown() end,
    Page = function(delta)
        if not Look:IsShown() then return false end
        Look:Page(delta)
        return true
    end,
})

TK.On("PLAYER_LEAVING_WORLD", function()
    if frame then frame:Hide() end
end)
