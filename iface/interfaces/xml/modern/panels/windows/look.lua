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
--
-- s6-ui-core (round 85): the XML twin's scripts; the window, its views and slots are look.xml's (core/xml.md).

local H = __tk
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin

local Look = {}
TK.Look = Look

-- the scripts look.xml names, and its build (its templates: the window, a slot)
local scripts = {}
local ui = TK.Xml.Load("look.xml", { scripts = scripts, elements = require("interfaces.modern.elements") })

-- The figure's background (0xRRGGBB), the box it is painted onto, as the character window's; the views in their order
-- (ids); each equipment record's place in the grid (look.xml's)
local BG, VIEWS, GRID = ui.BG, ui.VIEWS, ui.GRID

local frame

local function stateText(v)
    if v == 0xFF then return "" elseif v ~= 0 then return ": On" end
    return ": Off"
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

-- ----- look.xml's scripts -----

local making -- the index of the equipment slot being made (scripts.Slots), for its SlotPlace

function scripts.Own(f) TK.GetComponent("windows"):Own(f) end

function scripts.DragStart(self) self:StartMoving() end

function scripts.DragStop(self) self:StopMovingOrSizing() end

function scripts.BoxBackdrop(box)
    box:SetBackdrop({ bg = { BG[1] / 255, BG[2] / 255, BG[3] / 255, 1 }, edge = false, bgFile = "tk:white" })
end

function scripts.Figure(f) f.figure = f.box.figure end

-- Wire: a Trade or Group button is the game layer's look action (TK.Game.Look.ActionButton: 4A 00 or 2E on the left
-- press, UserLookPane::HandlePointerOrMouseEvent's type 1); changing it changes what the server sees.
function scripts.ActionButton(b) TK.Game.Look.ActionButton(b, b.kind) end

function scripts.ActionTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.tip.title, 1, 1, 1)
    GameTooltip:AddLine(self.tip.text, 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function scripts.Untip() GameTooltip:Hide() end

function scripts.GateNames(f) _G.TKLookTrade, _G.TKLookGroup = f.trade, f.group end

function scripts.Tab(b) b:GetParent().tabs[b.id] = b end

function scripts.View(view) view:GetParent().views[view.id] = view end

function scripts.ShowView(b) Look:ShowView(b.id) end

function scripts.Slots(f, build)
    f.slots = {}
    for i = 1, #GRID do
        making = i
        f.slots[i] = build:New("Slot", f.views.equipment)
    end
    making = nil
end

function scripts.SlotPlace(s)
    local cell = GRID[making]
    s:SetPoint("TOPLEFT", s:GetParent(), "TOPLEFT", 54 + cell.x * 58, -6 - cell.y * 38)
    s.index = making
end

function scripts.SlotTip(self)
    local _, slotName, _, name = H:GetLookItem(self.index)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(name ~= "" and name or slotName, 1, 1, 1)
    if name ~= "" then GameTooltip:AddLine(slotName, 0.7, 0.7, 0.7) end
    GameTooltip:Show()
end

function scripts.LegendPlace(f) f.legend.sf:SetPoint("TOPLEFT", f.views.legend, "TOPLEFT", 4, -6) end

function scripts.Close() frame:Hide() end

function scripts.Escape(f) TK.Escape:AddWindow(f, function() f:Hide() end) end

function scripts.Ticker(f) f:SetScript("OnUpdate", TK.Util.Throttled(0.2, function() showFigure(f) end)) end

local function build() return ui:New("Window") end

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
    for i, id in ipairs(VIEWS) do
        if id == frame.view then at = i end
    end
    self:ShowView(VIEWS[math.max(1, math.min(#VIEWS, at + delta))])
end

--- Opens the window on the last look, on its first view (UserLookPane::OnActivate ends in ShowMoreInfoView): the views'
--- window for the look (TK.Game.Views, below), shown when no interface's page takes it. Showing sends nothing.
local function showWindow()
    if not frame then frame = build() end
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
