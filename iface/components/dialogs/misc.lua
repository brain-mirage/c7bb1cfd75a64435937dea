-- s6-rules-dialogs: the music dialog (D-63, modal: UI head note 32), the world map (D-67), the minimap (D-66), the
-- papers (D-68, D-69), the profile (D-62) and a photo (D-70).
--
-- s6-modular-g (interfaces): the music dialog's, the papers' and the profile's sizes and places are the look's
-- (C.look.Music, Paper, Profile). The world map and the photo are whole here, as their geometry is what they do: the
-- map is 4a's 1024 x 768 pane, whose pixels its hit test, drag and view easing work in (a press on a node goes by
-- them), and the photo is laid on the world view's own tiles at its scale.

local C = TK.GetComponent("dialogs")
local K = C.kit
local W = TK.UI
local H = __tk

-- s6-ui-core r66: the complete shared music controls and existing folder-picker route.
require("components.dialogs.music")

-- D-67: the world map (WorldMapPane 0x005C2AC0), round 21 as 4a draws it: a 1024 x 768 pane showing the <map>.EPF
-- picture (frame 0, <map>.PAL) at 1:1, cut round the view's centre (GetMapSourceRect 0x005C36D0), with the nodes at
-- their picture positions less the view's top-left and the player's figure as the marker (OnPaint 0x005C3950). The view
-- opens on the current node and keeps at least half the pane inside the picture (ClampViewPosition 0x005C4740). A press
-- on the map off the nodes drags it, keeping the point under the pointer (HandlePointerOrMouseEvent); the arrows ease it
-- to the hovered node, and a walk to the player, a twentieth of the way every 20 ms (OnFrameUpdate 0x005C4250). A node
-- takes a press within 20 pixels of it (HitTestNode). A press on a node is DialogActions.Click(serial, node, hovered); on
-- the map, node -1. Field 0: the hovered node, which the pointer (over a reachable node) and the arrows (previous or next
-- reachable node) move. The view is the window's alone: nothing of it is sent.
-- Round 22: each node is WMSYMBOL.EPF's symbol (frame 1 for the hovered node or the walk's destination, else 0; in the
-- current palette, BARAM.PAL, as 4a blits it with none of its own) centred on its point, with its name in a box filled
-- at half strength (the port's m_alpha) in the current palette's colours by its state; the marker is s6-characters'
-- walking figure, centred on the player's point. Round 24: at sea on WM2 (HitTestSpecialRegions 0x005C5200) it is
-- s6-characters' boat (GetFigure('boat', 0): BOAT.EPF's back frame, the figure in walking frame 0, the front frame),
-- centred the same way. Known limitation: our label font is ours (Modern's still; 7.x's and 5.x's since round 99).
-- s6-ui-core (round 99): as OnPaint draws them, beside the real 7.5.2's and 5.33's pictures: the symbol at its frame's
-- rectangle less 6 each way from the point (m_nodeSymbol.bounds.Offset(-6, -6); WMSYMBOL's is (-5, -5)-(19, 19), so
-- centred it was drawn 1 pixel left and up); a look that has its own world map entry (C.look.WorldMap: 7.x's and
-- 5.x's) gives the names its font (text: the original's, measured by its advances) and draws no "At ..." line (OnPaint
-- draws no text but the names; the default look, Modern's, keeps it and its font); the marker last, over the nodes,
-- their boxes and names (OnPaint 0x005C3950 draws it after them). Drawing only.
-- s6-input (round 46; FOR s6-rules-dialogs): the pane covers the screen, as 4a's does (MapPane::CreateWorldMapPaneLayer
-- 0x0050F270 puts it at (0, 0)-(screen width, height) on its own layer under the dialogs'): the window is the whole game
-- window, black (OnPaint's fill in colour 0x80), and the 1024 x 768 pane (win.pane) is 4a's screen scaled to fit it as
-- 7.x's and 5.x's screens are (interfaces/screen.lua), clipping the picture, the nodes, their names and the marker at
-- its edges (OnPaint draws them all, clipped by the pane). A press off the nodes, on the window's sides too, is a press
-- on the map (node -1).
-- Wire: WorldMapPane::HandlePointerOrMouseEvent 0x005C40C0 and HandleKeyOrTextEvent 0x005C3E50: which node a press goes
-- to (nodeAt, by 4a's pixels: the pointer in the pane's own pixels, whatever its scale), the hovered node sent as field
-- 0, and the presses on the map (node -1); changing the hit test, the hover or the view arithmetic changes what the
-- server sees.
local Map = { look = "WorldMap" }
local Screen = require("interfaces.screen")

local PANE_W, PANE_H = 1024, 768

--- HitTestNode (0x005C37E0): a node takes the pointer strictly within 20 pixels of its point, 19 each way.
local NODE_REACH = 19

--- C's (int) of a float: toward zero.
local function int(v) return v < 0 and math.ceil(v) or math.floor(v) end

--- The original's font 0: GrafPort::GetLineHeight is always 12 (its metrics: 4a FontImageLib.cpp:29-36), and the
--- glyph loop puts a glyph's top 1 below its line's (the pen's y less the line, plus the glyph's top, plus 1:
--- GrafPort.cpp:1143-1148). For a look's text (C.look.WorldMap.text).
local LINE, GLYPH_TOP = 12, 1

--- OnPaint's colours: indices of the current palette (BARAM.PAL; Source-5's read of it when the packs have none).
local SELECTED_FILL, REACHABLE_FILL, OTHER_FILL, LIT_TEXT, DIM_TEXT = 4, 6, 0x86, 0x8F, 0x80
local BARAM = { [4] = { 171, 0, 0 }, [6] = { 171, 87, 0 }, [0x86] = { 99, 99, 99 }, [0x8F] = { 255, 255, 255 }, [0x80] = { 0, 0, 0 } }
local colours = {}

local function colour(index)
    if not colours[index] then
        local ok, r, g, b = H:GetPaletteColour("BARAM.PAL", index)
        local c = BARAM[index]
        colours[index] = ok and { r, g, b } or { c[1] / 255, c[2] / 255, c[3] / 255 }
    end
    return table.unpack(colours[index])
end

--- HitTestSpecialRegions (0x005C5200): WM2's three sea areas (map pixels, bounds included), where the player rides a boat;
--- x, y the marker's point in the pane.
local SEAS = { { 148, 230, 448, 550 }, { 600, 876, 1110, 1278 }, { 1058, 1140, 464, 854 } }

local function atSea(win, x, y)
    if win.name ~= "WM2" then return false end
    local ox, oy = PANE_W / 2 - int(win.viewX), PANE_H / 2 - int(win.viewY)
    for _, r in ipairs(SEAS) do
        if ox + r[1] <= x and x <= ox + r[2] and oy + r[3] <= y and y <= oy + r[4] then return true end
    end
    return false
end

--- ClampViewPosition: the centre at least half the pane inside the picture (the picture's corner at 0, 0).
local function clamp(win, x, y)
    if win.pw < PANE_W or x < PANE_W / 2 then x = PANE_W / 2 elseif x > win.pw - PANE_W / 2 then x = win.pw - PANE_W / 2 end
    if win.ph < PANE_H or y < PANE_H / 2 then y = PANE_H / 2 elseif y > win.ph - PANE_H / 2 then y = win.ph - PANE_H / 2 end
    return x, y
end

--- SetViewPosition: the view there at once (clamped), with nothing left to ease.
local function setView(win, x, y)
    win.targetX, win.targetY = x, y
    win.viewX, win.viewY = clamp(win, x, y)
    Map.layout(win)
end

--- The pointer (or the screen pixel x, y: a move's own point) in the pane's pixels (from its top left), by the pane's fit
--- (Map.place), which needs no layout: a move kept for a window built later maps the same (s6-input rounds 46-47).
local function pointer(win, x, y)
    if x then
        local u = TK.UIScale()
        x, y = x / u, y / u
    else
        x, y = TK.Util.CursorRoot()
    end
    local f = win.fit
    return (x - f.left) / f.s, (f.height - y - f.top) / f.s
end

--- s6-input (round 47; the head's review of round 46, P2). WIRE: a point on 4a's pane, (0, 0)-(1024, 768). 4a's cursor
--- never leaves its screen (MainWindowProc clamps it, Application.cpp:1209-1216); a point under the black bars round
--- the fitted pane is on none of 4a's, so it reaches no node, not even one the pane clips out of sight (a node's visible
--- part within the pane keeps HitTestNode's 20 pixels). Letting it hit a node changes which 3F the server gets.
local function onPane(win, px, py)
    -- The look's smaller FIELD viewport clips at its own edges; node hit tests within it retain 4a's pixels.
    -- WIRE: a clipped-out node must not become a destination (0x005C40C0); changing this changes the 3F sent.
    return px >= 0 and px < (win.drawWidth or PANE_W) and py >= 0 and py < (win.drawHeight or PANE_H)
end

--- s6-input (round 47; Astra's review s6-input-self-47-1). WIRE: 4a's point for an input at a screen pixel: on the pane
--- as it is; beside it (under a bar), clamped to the pane's edges when the window holds the mouse capture (a button down:
--- SetCapture, and MainWindowProc clamps every point to the screen, Application.cpp:1209-1216), else none, as 4a gets no
--- move outside its window without the capture. Changing it moves where a drag puts the view and which node a hover or a
--- release reaches, so which 3F the server gets.
local function panePoint(win, x, y, captured)
    local px, py = pointer(win, x, y)
    if onPane(win, px, py) then return px, py end
    if not captured then return nil end
    return math.max(0, math.min((win.drawWidth or PANE_W) - 1, px)), math.max(0, math.min((win.drawHeight or PANE_H) - 1, py))
end

--- HitTestNode (0x005C37E0): the first node within 20 pixels of a point of the pane (strictly), or -1.
local function nodeAt(win, px, py)
    local c = win.view and win.view.contents
    local left, top = int(win.viewX - PANE_W / 2), int(win.viewY - PANE_H / 2)
    for i, n in ipairs(c and c.nodes or {}) do
        local x, y = (n[2] or 0) - left, (n[3] or 0) - top
        if x - 20 < px and px < x + 20 and y - 20 < py and py < y + 20 then return i - 1 end
    end
    return -1
end

--- HandlePointerOrMouseEvent (0x005C40C0)'s left press that finds no destination: the drag starts, keeping the picture's
--- point under the pointer (ScreenToMapPoint); a press beside the pane, at its edge (panePoint).
local function startDrag(win)
    local x, y = GetCursorPosition()
    local px, py = panePoint(win, x, y, true)
    win.dragX, win.dragY = int(px + win.viewX - PANE_W / 2), int(py + win.viewY - PANE_H / 2)
end

--- UpdateHoverFromMouseStrict (0x005C50F0) at a point of the pane: the reachable node under it, else the hover kept.
local function hoverAt(win, px, py)
    local c = win.view.contents
    local node = nodeAt(win, px, py)
    if node >= 0 and c.reachable and c.reachable[node + 1] and node ~= win.hovered then
        win.hovered = node
        win:Paint()
    end
end

--- s6-input (rounds 46-47; head note, QA's next41 2a; Astra's review s6-input-self-46-3; the head's review of round 46).
--- WIRE: 4a hovers from the pointer only at a pointer move dispatched to the pane (HandlePointerOrMouseEvent 0x005C40C0
--- type 0), the one MainWindowProc posts before every button and wheel event at an unchanged point included, and not
--- while it drags (the move moves the view then); the pane opens on the current node, and a node that appears or slides
--- under a still pointer (the map opening, the view easing) changes nothing. Live, every move the logic dispatched to this
--- map comes here at its own point and in its place among the inputs (TK_WORLD_MAP_MOVE below, or kept for the window
--- until it is built); the logic decided at the move's dispatch that the map took it and walked to no node
--- (InputHost.MapHover). The hover is field 0 of the map's later records (the arrows step from it, Enter travels to it):
--- hovering without a move, or missing one, changes which 3F the server gets. During a drag each move puts the view
--- there at once (round 47, Astra's review s6-input-self-47-1: case 0's SetViewPosition, before a release in the same
--- frame hit-tests the view; not a frame later in Map.tick). captured: the move came under the mouse capture (panePoint);
--- walking: the map walked to a node as the move was dispatched, so the move drags but hovers nothing (case 0's
--- m_navigationActive test; Astra's review s6-input-self-47-2).
local function mapMove(win, x, y, captured, walking)
    win.pointerX, win.pointerY = x, y
    local px, py = panePoint(win, x, y, captured)
    if not px then return end
    if win.dragX then
        setView(win, win.dragX - px + PANE_W / 2, win.dragY - py + PANE_H / 2)
    elseif not walking then
        hoverAt(win, px, py)
    end
end

--- Offline (no logic dispatches moves: the UI's previews and tests), a frame's change of the pointer's pixel is the move;
--- the map then takes it only with no modal pane up (EventDispatcher::DispatchEvent asks the modal list first) and no
--- walk. Live, never: every move came through mapMove.
local function offlineMove(win)
    if H:IsLiveInput() then return end
    local x, y = GetCursorPosition()
    if x == win.pointerX and y == win.pointerY then return end
    win.pointerX, win.pointerY = x, y
    local c = win.view and win.view.contents
    if not c or c.walking or win.dragX or H:DialogModal() then return end
    local px, py = panePoint(win, x, y, false)
    if px then hoverAt(win, px, py) end
end

--- s6-input (round 47): the moves dispatched to a map whose window is not built yet ({ serial, { x, y }... }), handed to
--- it when it is (Map.update).
local waiting = { serial = 0 }

--- Its left release: the drag ends and UpdateHoverFromMouse (WorldMapPane.cpp:498) hovers a reachable node under the
--- pointer, or none (review r21, 1).
local function endDrag(win)
    win.dragX = nil
    local x, y = GetCursorPosition()
    win.pointerX, win.pointerY = x, y
    local c = win.view.contents
    local node = nodeAt(win, panePoint(win, x, y, true)) -- s6-input (round 47): the release, under the capture (panePoint)
    if node == -1 or (c.reachable and c.reachable[node + 1]) then win.hovered = node end
    win:Paint()
end

--- 4a's pane is the screen (s6-input round 46): the window covers the game window, the pane is fitted to it. Again when
--- the window's size changes (Map.tick).
function Map.place(win)
    win:ClearAllPoints()
    win:SetAllPoints(UIParent)
    local s, left, top = Screen.Fit(win.drawWidth or PANE_W, win.drawHeight or PANE_H)
    win.pane:SetSize(win.drawWidth or PANE_W, win.drawHeight or PANE_H)
    win.pane:SetScale(s)
    win.pane:ClearAllPoints()
    win.pane:SetPoint("TOPLEFT", win, "TOPLEFT", left / s, -top / s)
    win.fitW, win.fitH = GetScreenWidth(), GetScreenHeight()
    win.fit = { s = s, left = left, top = top, height = win.fitH }
end

function Map.build()
    local win = CreateFrame("Frame", nil, UIParent)
    win:SetFrameStrata("DIALOG")
    win:EnableMouse(true)
    win.controls = {}
    local bg = win:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(win)
    bg:SetColorTexture(0, 0, 0, 1)
    -- 4a's pane: a scroll frame that never scrolls clips what is in it; the wheel and the presses stay the window's
    win.pane = CreateFrame("ScrollFrame", nil, win)
    win.pane:SetSize(PANE_W, PANE_H)
    win.pane:EnableMouse(false)
    win.pane:EnableMouseWheel(false)
    win.picture = win.pane:CreateTexture(nil, "BORDER")
    win.picture:SetPoint("TOPLEFT", win.pane, "TOPLEFT", 0, 0)
    win.picture:Hide()
    win.nodes = {}
    -- the marker on a layer of its own over the nodes' buttons (child frames of the pane, drawn over its textures):
    -- OnPaint draws it last (Map.marker keeps the layer above them); it takes no pointer, so presses still find the nodes
    win.markerLayer = CreateFrame("Frame", nil, win.pane)
    win.markerLayer:SetAllPoints(win.pane)
    win.marker = win.markerLayer:CreateTexture(nil, "OVERLAY")
    win.status = W.Label(win.pane, "", 12, W.white, "LEFT")
    win.status:SetPoint("BOTTOMLEFT", win.pane, "BOTTOMLEFT", 12, 10)
    Map.place(win)
    win:SetScript("OnMouseDown", function(_, button, double)
        K.Pointer(win, -1, button, true)
        local c = win.view and win.view.contents
        -- The press's UpdateHoverFromMouse finds no node off the nodes, so nothing is hovered (review r21, 1) and the drag
        -- starts; a double-click's second press (event type 2: the host's third argument, live and offline) is not handled.
        if button == "LeftButton" and c and not c.walking and not double then
            win.hovered = -1
            win:Paint()
            startDrag(win)
        end
    end)
    win:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and win.dragX then endDrag(win) end
        K.Pointer(win, -1, button, false)
    end)
    win:SetScript("OnUpdate", function(_, elapsed) Map.tick(win, elapsed) end)
    function win:Values() return { tostring(self.hovered or -1) } end
    --- OnPaint's states: walking, the destination lit and the rest dim; else the hovered node lit, a reachable one on
    --- brown, the rest dim.
    function win:Paint()
        local c = self.view.contents
        for i, b in ipairs(self.nodes) do
            local idx = i - 1
            local selected, fill, text
            if c.walking then
                selected = idx == c.target
                fill, text = selected and SELECTED_FILL or OTHER_FILL, selected and LIT_TEXT or DIM_TEXT
            elseif idx == self.hovered then
                selected, fill, text = true, SELECTED_FILL, LIT_TEXT
            else
                local reachable = c.reachable and c.reachable[i]
                selected, fill, text = false, reachable and REACHABLE_FILL or OTHER_FILL, reachable and LIT_TEXT or DIM_TEXT
            end
            local key
            if self.mapArt then key = self.mapArt.symbol(b, selected and 1 or 0)
            else key = TK.Art.Image("WMSYMBOL.EPF", selected and 1 or 0, "BARAM.PAL") end
            if key then
                b.symbol:SetTexture(key)
                b.symbol:SetVertexColor(1, 1, 1, 1)
            else
                b.symbol:SetTexture("tk:circle")
                b.symbol:SetVertexColor(selected and 1 or 0.8, selected and 0.85 or 0.8, selected and 0.2 or 0.8, 1)
            end
            local r, g, bl = colour(fill)
            b.fill:SetColorTexture(r, g, bl, 0.5)
            b.label:SetTextColor(colour(text))
        end
    end
    win:Hide()
    return win
end

--- The picture's cut, the nodes and the marker for the view as it stands.
function Map.layout(win)
    local c = win.view and win.view.contents
    if not c then return end
    local left, top = int(win.viewX - PANE_W / 2), int(win.viewY - PANE_H / 2)
    if win.key then
        local w, h = math.min(PANE_W, win.pw), math.min(PANE_H, win.ph)
        win.cut = { left, top, w, h }
        win.picture:SetTexCoord(left / win.pw, (left + w) / win.pw, top / win.ph, (top + h) / win.ph)
        win.picture:SetSize(w, h)
    end
    for i, n in ipairs(c.nodes or {}) do
        local b = win.nodes[i]
        local x, y = (n[2] or 0) - left, (n[3] or 0) - top
        b:ClearAllPoints()
        -- s6-ui-core (round 98): from its top left, at whole pixels: the node's button is 39 wide (HitTestNode 0x005C37E0's
        -- strict 20 pixels each way), so placed by its centre its edges fell on half pixels, which the host rounds; a 5.x
        -- hut anchored to it was drawn 1 pixel right and up of 5.33's. WIRE: the button takes the press on the node
        -- (K.Wire) from x - 19 to x + 19 and y - 19 to y + 19, 4a's square, and its hit test (Map.update) refuses the
        -- right and bottom edges the host's raycast includes; moving it changes which node a press travels to.
        b:SetPoint("TOPLEFT", win.pane, "TOPLEFT", x - NODE_REACH, -(y - NODE_REACH))
        -- GetNodeLabelRect (0x005C4850): the name's width + 12 by a line + 4, centred under the point from 8 below it;
        -- the text 6 in from its left, its line 2 below the top (the pen 2 above the bottom). s6-ui-core (round 99): in
        -- a look's text (the original's font) by the original's measures: its advances (our font string measures one
        -- more), its 12-pixel line (ours is 13) and the glyph 1 below the line; the 5.x names were drawn 1 pixel high.
        local text = win.mapLook and win.mapLook.text
        local tw = text and text.width(b.label:GetText())
        local w = (tw or b.label:GetStringWidth()) + 12
        local h = (text and LINE or b.label:GetStringHeight()) + 4
        b.fill:ClearAllPoints()
        b.fill:SetPoint("TOPLEFT", win.pane, "TOPLEFT", x - int(w / 2), -(y + 8))
        b.fill:SetSize(w, h)
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT", b.fill, "TOPLEFT", 6, -(2 + (text and GLYPH_TOP or 0)))
        -- s6-input (round 46): every node drawn, the pane clipping it at its edges as OnPaint's are (one half off the pane
        -- shows its other half, and that half takes a press as HitTestNode's 20 pixels do)
        b:Show()
        b.label:Show()
        b.fill:Show()
    end
    Map.marker(win)
end

--- DrawPlayerMarker (0x005C48B0): the player's last human look walking in place (s6-characters' 'walk': the frame showing
--- now, a new one every 150 ms), its picture centred on the player's point; at sea on WM2, frame 0 in a boat.
function Map.marker(win)
    local c = win.view and win.view.contents
    if not c then return end
    local p = c.player or {}
    local x, y = int(p[1] or 0) - int(win.viewX - PANE_W / 2), int(p[2] or 0) - int(win.viewY - PANE_H / 2)
    local key, fw, fh
    win.atSea = atSea(win, x, y)
    if win.atSea then
        key, fw, fh = H:GetFigure("boat", 0)
        if key == "" then key, fw, fh = H:GetFigure("walk0", 0) end
    else
        key, fw, fh = H:GetFigure("walk", 0)
    end
    win.marker:ClearAllPoints()
    if key ~= "" then
        win.marker:SetTexture(key)
        win.marker:SetVertexColor(1, 1, 1, 1)
        local scale = win.mapArt and win.mapArt.figureScale or 1
        win.marker:SetSize(fw * scale, fh * scale)
    else
        win.marker:SetTexture("tk:circle")
        win.marker:SetVertexColor(1, 0.3, 0.2, 1)
        win.marker:SetSize(12, 12)
    end
    win.marker:SetPoint("CENTER", win.pane, "TOPLEFT", x, -y)
    -- drawn last (OnPaint): above the nodes' buttons, which take the pane's level + 1 (the window's level may change)
    win.markerLayer:SetFrameLevel(win.pane:GetFrameLevel() + 2)
end

--- OnFrameUpdate's view, every 20 ms: a twentieth of the way to the target (the player while it walks), or there.
function Map.tick(win, elapsed)
    local c = win.view and win.view.contents
    if not c or not win.viewX then return end
    if GetScreenWidth() ~= win.fitW or GetScreenHeight() ~= win.fitH then Map.place(win) end
    offlineMove(win)
    if win.dragX then
        -- s6-input (round 47): offline only; live, each dispatched move put the view there in its order (mapMove)
        if not H:IsLiveInput() then
            local px, py = pointer(win)
            setView(win, win.dragX - px + PANE_W / 2, win.dragY - py + PANE_H / 2)
        end
        return
    end
    win.acc = math.min((win.acc or 0) + (elapsed or 0), 1)
    local moved = false
    while win.acc >= 0.02 do
        win.acc = win.acc - 0.02
        if c.walking and c.player then win.targetX, win.targetY = c.player[1], c.player[2] end
        local dx, dy = (win.targetX - win.viewX) / 20, (win.targetY - win.viewY) / 20
        if math.abs(dx) < 0.05 and math.abs(dy) < 0.05 then
            if win.viewX ~= win.targetX or win.viewY ~= win.targetY then
                win.viewX, win.viewY = clamp(win, win.targetX, win.targetY)
                moved = true
            end
        else
            win.viewX, win.viewY = clamp(win, win.viewX + dx, win.viewY + dy)
            moved = true
        end
    end
    if moved or c.walking then Map.layout(win) else Map.marker(win) end
end

function Map.update(win, view)
    local c = view.contents
    local nodes = c.nodes or {}
    if win.opened then
        local name = tostring(c.map or ""):upper()
        win.name = name
        local key, pw, ph
        -- the look's own world map entry (7.x's, 5.x's): its picture for a map (select), its text for the names
        win.mapLook = C.look.WorldMap
        win.mapArt = win.mapLook and win.mapLook.select and win.mapLook.select(name)
        if win.mapArt then key, pw, ph = win.mapArt.image(name .. ".EPF", 0, name .. ".PAL") end
        if not key and name ~= "" then key, pw, ph = TK.Art.Image(name .. ".EPF", 0, name .. ".PAL") end
        win.drawWidth, win.drawHeight = win.mapArt and win.mapArt.width, win.mapArt and win.mapArt.height
        Map.place(win)
        win.key, win.pw, win.ph = key, pw or PANE_W, ph or PANE_H
        if key then
            win.picture:SetTexture(key)
            win.picture:Show()
        else
            win.picture:Hide()
        end
        win.hovered = c.hovered
        win.dragX, win.acc = nil, 0
        win.pointerX, win.pointerY = GetCursorPosition() -- s6-input (round 46): a still pointer hovers nothing (offlineMove)
        for i, n in ipairs(nodes) do
            local b = win.nodes[i]
            if not b then
                b = CreateFrame("Button", nil, win.pane)
                b:SetSize(2 * NODE_REACH + 1, 2 * NODE_REACH + 1)
                b.reach = NODE_REACH -- the node's point is (reach, reach) from its top left (a look's symbol: mapArt.symbol)
                b.symbol = b:CreateTexture(nil, "ARTWORK")
                b.symbol:SetPoint("CENTER", b, "TOPLEFT", NODE_REACH, -NODE_REACH) -- on the node's point
                b.symbol:SetSize(12, 12)
                b.fill = win.pane:CreateTexture(nil, "ARTWORK")
                b.label = W.Label(win.pane, "", 11, W.white, "LEFT")
                b.__dialogParent = win
                local idx = i - 1
                -- s6-ui-core (round 98, Astra's self-review): WIRE: HitTestNode (0x005C37E0) is strict, but the host's
                -- raycast takes the button's right and bottom edges, x + 20 and y + 20; there the press is no node's (-1),
                -- as 4a's. Changing it changes which node a press sends the server to.
                b.__dialogHitTest = function() return nodeAt(win, pointer(win)) == idx end
                K.Wire(win, b, idx)
                -- Round 25: a press on an unreachable node with nothing hovered finds no destination either (the press's
                -- UpdateHoverFromMouse keeps the hover at -1), so it drags the picture as a press off the nodes does.
                b:HookScript("OnMouseDown", function(_, button, double)
                    local cc = win.view and win.view.contents
                    if button == "LeftButton" and cc and not cc.walking and not double
                        and not (cc.reachable and cc.reachable[idx + 1]) and (win.hovered or -1) == -1 then
                        startDrag(win)
                    end
                end)
                b:HookScript("OnMouseUp", function(_, button)
                    if button == "LeftButton" and win.dragX then endDrag(win) end
                end)
                win.nodes[i] = b
            end
            b.label:SetText(K.Text(n[1]))
            if win.mapLook and win.mapLook.text then win.mapLook.text.style(b.label) else b.label:SetFont(11, "") end
            local key, sw, sh = TK.Art.Image("WMSYMBOL.EPF", 0, "BARAM.PAL")
            if not win.mapArt then
                -- OnPaint's BlitTileContextAt(x, y, symbol): the frame's rectangle (both frames' alike) less 6 each way
                -- from the node's point (the constructor's bounds.Offset(-6, -6)); the picture's drawn pixels from
                -- their origin in it
                b.symbol:ClearAllPoints()
                local fl, ft = TK.Art.FrameRect(key)
                if key and fl then
                    local ox, oy = TK.Art.Origin(key)
                    b.symbol:SetPoint("TOPLEFT", b, "TOPLEFT", NODE_REACH + fl - 6 + ox, -(NODE_REACH + ft - 6 + oy))
                    b.symbol:SetSize(sw, sh)
                else
                    b.symbol:SetPoint("CENTER", b, "TOPLEFT", NODE_REACH, -NODE_REACH) -- on the node's point
                end
            end
        end
        for i = #nodes + 1, #win.nodes do
            win.nodes[i]:Hide()
            win.nodes[i].label:Hide()
            win.nodes[i].fill:Hide()
        end
        local cur = nodes[(c.current or 0) + 1] or {}
        setView(win, cur[2] or PANE_W / 2, cur[3] or PANE_H / 2)
        -- s6-input (round 47): the moves dispatched to this map before its window was built, in their order (waiting)
        if waiting.serial == view.serial then
            for _, m in ipairs(waiting) do mapMove(win, m[1], m[2], m[3], m[4]) end
            waiting = { serial = 0 }
        end
    end
    local cur = nodes[(c.current or 0) + 1]
    win.status:SetShown(win.mapLook == nil) -- OnPaint draws no text but the names: the default look's (Modern's) line
    win.status:SetText((cur and ("At " .. K.Text(cur[1])) or "") .. (c.walking and "   (travelling)" or ""))
    Map.layout(win)
    win:Paint()
end

--- The arrows move the hover to the previous or next reachable node and ease the view to it (HandleKeyOrTextEvent
--- 0x80-0x83, StartViewAnimation). Wire: the hovered node is the dialog's field 0 (win:Values) that its reply sends, so
--- changing which keys count or which node an arrow reaches changes what the server sees.
function Map.key(win, key)
    local c = win.view and win.view.contents
    if not c or c.walking then return false end
    offlineMove(win) -- s6-input (round 46): offline, a move before this key hovers first, in 4a's order
    local bare = TK.Util.BareKey(key)
    local step = (bare == "LEFT" or bare == "UP") and -1 or (bare == "RIGHT" or bare == "DOWN") and 1 or nil
    if not step then return false end
    local n = #(c.nodes or {})
    for i = 1, n - 1 do
        local idx = ((win.hovered or 0) + step * i) % n
        if c.reachable[idx + 1] then
            win.hovered = idx
            local node = c.nodes[idx + 1]
            win.targetX, win.targetY = clamp(win, node[2] or 0, node[3] or 0)
            win:Paint()
            return true
        end
    end
    return false
end

-- s6-input (round 47; the head's review of round 46, P1). WIRE: every move the logic dispatched to a world map (its serial:
-- InputHost.MapHover; UIHost.Live.MapMove), in its place among the inputs: to that map's window (mapMove), or, while the
-- window is not built yet (the 2E's map before the UI's next refresh), kept for it and handed to it as it is built
-- (Map.update), which the dialogs' key hook and the pointer's sync do before any later input reaches it. A move dropped
-- here leaves another node hovered than 4a's, and so another 3F.
TK.On("TK_WORLD_MAP_MOVE", function(_, x, y, serial, captured, walking)
    local win = C.windows[serial]
    if win and win.renderer == Map and win.view then
        mapMove(win, x, y, captured, walking)
        return
    end
    if waiting.serial ~= serial then waiting = { serial = serial } end
    waiting[#waiting + 1] = { x, y, captured, walking }
end)

C.renderers.WorldMapPane = Map

-- D-66: the minimap, the close button (6). s6-world-view (round 17, the owner's revision of plan D26, 2026-10-01): the
-- model's dialog has no window of its own. The map window (core/mapwindow.lua) takes its place: it opens on M
-- and with the dialog (the server's 70), closes when the dialog closes, and its close box and Escape press the dialog's
-- close button (6). The round-19 expanded view that was here is that window now.
C.renderers.MiniMapDialog = {
    hidden = true,
    build = function() return K.Window(10, 10, "") end,
    update = function() end,
}

-- D-68, D-69: the paper's text (1; writable: an edit that takes Enter). Esc (control 0, out of sight) is done: a
-- writable paper then sends its text.
-- Wire: EditablePaperPane::OnControlCommand 0x00545220: done with the text as field 0 (a writable paper's own, else the
-- server's); changing it changes what the server sees.
local Paper = { look = "Paper" }

function Paper.build()
    local L = C.look.Paper
    local win = K.Window(L.width, L.height, "Paper")
    win.edit = K.Edit(win, 1, L.editWidth, L.editHeight, true)
    win.text = K.Block(win, 13)
    win.plainText = win.text
    -- One common viewport for paper bodies; looks supply only its rectangle, text style and bar.
    function win:ReadOnlyBody()
        local sf = self.readOnlyScroll
        if not sf then
            sf = W.ScrollArea(self)
            self.readOnlyScroll = sf
            sf.text = K.Block(sf.content, 13)
        end
        self.plainText:Hide()
        self.text = sf.text
        return sf
    end
    function win:PlainPaperText()
        local sf = self.readOnlyScroll
        if sf then sf:Hide() sf.track:Hide() sf.text:Hide() end
        self.text = self.plainText
    end
    -- Wire: ScrollablePane::HandlePointerOrMouseEvent (4a 0x0055EF50) scrolls locally;
    -- the native bar keeps its one-line notch, Modern keeps the common widget's 40-pixel step.
    -- No typed/control command is raised: EditablePaperPane::SendEditedText (0x00545880)
    -- still reads the unchanged field only on completion. Changing that routing changes what the server sees.
    win.edit:EnableMouseWheel(true)
    win.edit:SetScript("OnMouseWheel", function(self, delta)
        local sf = self.scrollBar
        if sf then sf:GetScript("OnMouseWheel")(sf, delta)
        else self:SetVerticalScroll(self:GetVerticalScroll() - delta * 40) end
    end)
    L.place(win)
    function win:Values() return { self.writable and self.edit:GetText() or K.Text(self.view.contents.text) } end
    return win
end

function Paper.update(win, view)
    local c = view.contents
    if not win.opened then return end
    -- s6-interface-5x-b (round 6): a look that sizes the paper by the packet's cells (5.x's: 4a's and 5.33's window)
    if C.look.Paper.fit then C.look.Paper.fit(win, c) end
    win.writable = c.writable == true
    win.edit:SetShown(win.writable)
    win.text:SetShown(not win.writable)
    if win.writable then
        K.SetEdit(win.edit, c.text)
        win.edit:SetFocus()
        -- Wire: 4a BuildControlsWithText (0x00545250) resets the initial selection to (0,0)
        -- after activating control 1. The host activates on a later frame, so reset once after
        -- focus is active; subsequent selection and Tab retain the ordinary edit behavior.
        -- SendEditedText (0x00545880) sends this field: changing this caret changes what the server sees.
        win.edit:SetScript("OnUpdate", function(self)
            if not self:HasFocus() then return end
            self:SetCursorPosition(0)
            self:SetScript("OnUpdate", nil)
        end)
    else
        win.text:SetText(K.Text(c.text))
        local sf = win.readOnlyScroll
        if sf and win.text == sf.text then
            -- 4a GetScrollRange/GetScrollOffset (0x0058EBF0/0x0058ED20): native paper
            -- counts whole lines, excluding the glyph box's margin. Modern uses its font's height.
            local height = win.text:GetStringHeight()
            if sf.paperLineHeight then
                local step = sf.paperLineHeight
                height = step * math.floor(height / step + 0.5)
            end
            height = math.max(sf:GetHeight(), height)
            win.text:SetHeight(height)
            sf.content:SetHeight(height)
            -- BuildControlsWithText (0x00545250) opens at the top, including a reused window.
            -- Read-only never acquires the edit focus or sends 23 (OnControlCommand 0x00545220);
            -- changing its focus/completion routing changes what the server sees.
            sf:Show()
            sf:ScrollToTop()
        end
    end
end

C.renderers.EditablePaperPane = Paper

-- D-62: the text (1, takes Enter), OK (2); no cancel control. Field 0: the text. s6-interface-5x-b (round 6): with a look
-- drawn from the old art (L.cancel: 5.x's), 4a's legacy branch's CANCEL (3), which the rules declare then
-- (DialogRules.LegacyLayouts).
-- Wire: ProfileDialog::OnControlCommand 0x0053FDC0: OK with the text as field 0, CANCEL (3) nothing; changing it changes
-- what the server sees.
local Profile = { look = "Profile" }

function Profile.build()
    local L = C.look.Profile
    local win = K.Window(L.width, L.height, "Profile")
    win.edit = K.Edit(win, 1, L.editWidth, L.editHeight, true)
    win.edit:SetMaxLetters(255)
    win.ok = K.Button(win, 2, "OK", L.button)
    if L.cancel then win.cancel = K.Button(win, 3, "CANCEL", L.button) end -- s6-interface-5x-b: the legacy branch's
    function win:Values() return { self.edit:GetText() } end
    L.place(win)
    return win
end

function Profile.update(win, view)
    if not win.opened then return end
    K.SetEdit(win.edit, view.contents.text or "")
    win.edit:SetFocus()
end

C.renderers.ProfileDialog = Profile

-- D-70: a photo (PhotoPane 0x00549620), round 21: the picture alone, 17 x 15 tiles (816 x 720), laid one tile (48, 48)
-- in from the corner of the world view's active area (its middle 17 x 15 cells), at the world view's scale. The picture
-- is s6-world-view's, by texture key: live:photo:<map>:<shape>:<facing>:<column>:<row>:<serial>, from the packet's
-- fields (the map id, u16 at 1; the shape, the low byte of the u16 at 3; the facing, 5; the column, 6; the row, 7) and
-- the window's serial (round 22). Until that hook is in the build the photo stays black (H:HasLiveTexture). A key or a
-- click closes it (the model's).
-- Wire: a release anywhere on it goes to the model as control -1, and a key through the dialogs' key hook, which close
-- it as 4a's PhotoPane does (0x00549620); changing them changes what the server sees.
local Photo = {}

--- The photo's texture key from the packet (raw, opcode first) and the window's serial, new for each 5A (s6-world-view
--- round 26: a photo received again is drawn again). (Review r21, 3: not a renderer's key handler.)
local function textureKey(packet, serial)
    local function b(i) return packet:byte(i + 1) or 0 end
    return string.format("live:photo:%d:%d:%d:%d:%d:%d", b(1) * 256 + b(2), b(4), b(5), b(6), b(7), serial or 0)
end

function Photo.place(win)
    local world = TK.GetComponent("worldview")
    local f = world and world.frame
    local s, anchor = 1, UIParent
    if f and f:IsShown() then
        -- s6-world-view (round 31): the picture's own scale (its tile's size); with Auto Extend Outer Area the frame is
        -- the window's size, not the picture's.
        s = world:TileSize() / 48
        anchor = f
    end
    win:SetSize(816 * s, 720 * s)
    -- The active area's corner is half of it (408, 360) from the picture's centre; the photo is one tile in from it.
    win:SetPoint("TOPLEFT", anchor, "CENTER", (48 - 408) * s, (360 - 48) * s)
end

function Photo.build()
    local win = CreateFrame("Frame", nil, UIParent)
    win:SetFrameStrata("DIALOG")
    win:EnableMouse(true)
    win.controls = {}
    local black = win:CreateTexture(nil, "BACKGROUND")
    black:SetAllPoints(win)
    black:SetColorTexture(0, 0, 0, 1)
    win.picture = win:CreateTexture(nil, "ARTWORK")
    win.picture:SetAllPoints(win)
    win:SetScript("OnMouseUp", function(_, button) K.Pointer(win, -1, button, false) end)
    win:Hide()
    return win
end

function Photo.update(win, view)
    if not win.opened then return end
    win.key = textureKey(view.contents.packet or "", view.serial)
    win.picture:SetShown(H:HasLiveTexture(win.key))
    win.picture:SetTexture(win.key)
end

C.renderers.PhotoPane = Photo
