-- s6-devtools (round 3; the owner, 2026-10-05): the Debug page's readouts and world aids (settings.lua):
--   * the frame time and FPS (moved from Interface, the same readout at the same place), a graph of each frame's time, the
--     performance counters (C#'s LuaApi.Debug), and the map's line;
--   * the marks on the ground (C#'s WorldDebug, drawn in every mode) and the tile inspector's tooltip;
--   * Detached Camera: the view leaves the player; while it is on every key is the UI's (C#'s Bootstrap.UiKeysNow, the
--     wire's note there) and the hook below moves the view with them; a press on the world is on no map (UIHost.LiveClick)
--     and a drag there moves the view too (round 4), the wheel zooms 3D.
-- Drawing and reading only: nothing here sends anything.

local C = TK.GetComponent("debug")
local W = TK.UI
local H = __tk
local U = TK.Util
local R = CS.TK.Modular.Draw.WorldRenderers

local MARKS = { "grid", "coordinates", "blocked", "warps", "lights", "windows" }
local BARS, BAR_W, GRAPH_H, GRAPH_MS = 90, 2, 48, 50
local PAD = 6

local function inWorld() return TK.GameState:InWorld() end

--- The hint design's 3.7/3.9: after editing local TOML files, reread them on the next drawing frame. Both the Debug
--- page and the named binding use this action; no game action or packet is attached to it.
function C:ReloadWorldHints() H:ReloadWorldHints() end
TK.Bindings:RegisterCommand("RELOADWORLDHINTS", "Reload World Hints", function() C:ReloadWorldHints() end)

function C:OnEnable()
    -- Show Frame Time, as Interface had it: the average over half a second, at the top right.
    local ft = CreateFrame("Frame", "TKFrameTime", UIParent)
    ft:SetFrameStrata("TOOLTIP")
    ft:SetSize(140, 16)
    ft:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -8, -4)
    ft.text = W.Label(ft, "", 11, { 0.7, 1, 0.7 }, "RIGHT")
    ft.text:SetFont(11, "OUTLINE")
    ft.text:SetPoint("RIGHT", ft, "RIGHT", 0, 0)
    self.frame = self:Own(ft)

    -- The panel under it: the graph, the counters, the map's line, each shown by its switch.
    local panel = CreateFrame("Frame", "TKDebugPanel", UIParent)
    panel:SetFrameStrata("TOOLTIP")
    panel:SetBackdrop({ bg = { 0, 0, 0, 0.6 } })
    self.panel = self:Own(panel) -- placed by C:Layout

    local graph = CreateFrame("Frame", "TKDebugGraph", panel)
    graph:SetSize(BARS * BAR_W, GRAPH_H)
    graph.bars = {}
    for i = 1, BARS do
        local t = graph:CreateTexture(nil, "ARTWORK")
        t:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", (i - 1) * BAR_W, 0)
        t:SetSize(BAR_W, 1)
        t:SetColorTexture(0.4, 1, 0.4, 0.9)
        graph.bars[i] = t
    end
    -- the 60 and 30 frames a second lines (16.7 and 33.3 ms)
    for _, ms in ipairs({ 1000 / 60, 1000 / 30 }) do
        local t = graph:CreateTexture(nil, "OVERLAY")
        t:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", 0, ms / GRAPH_MS * GRAPH_H)
        t:SetSize(BARS * BAR_W, 1)
        t:SetColorTexture(1, 1, 1, 0.35)
    end
    graph.label = W.Label(graph, "", 10, { 0.85, 0.85, 0.85 }, "LEFT")
    graph.label:SetPoint("TOPLEFT", graph, "TOPLEFT", 2, -1)
    panel.graph = graph
    panel.counters = W.Label(panel, "", 11, { 0.85, 0.95, 1 }, "LEFT")
    panel.map = W.Label(panel, "", 11, { 1, 0.95, 0.75 }, "LEFT")

    -- The tile inspector's tooltip, beside the pointer (GameTooltip's look; the world's own tooltip may show too).
    local tip = CreateFrame("Frame", "TKDebugInspector", UIParent)
    tip:SetFrameStrata("TOOLTIP")
    tip:SetBackdrop({ bg = { 0.03, 0.03, 0.06, 0.92 }, edge = { 0.6, 0.6, 0.65, 1 } })
    tip.text = W.Label(tip, "", 12, W.white, "LEFT")
    tip.text:SetPoint("TOPLEFT", tip, "TOPLEFT", 9, -9)
    tip:Hide()
    self.inspector = self:Own(tip)

    -- One clock for every readout: each frame's time (the graph's ring), and the readouts' own pace.
    local times, head = {}, 0
    for i = 1, BARS do times[i] = 0 end
    local acc, frames, worst, graphWait, countersWait, mapWait, tipWait = 0, 0, 0, 0, 0, 0, 0
    local watcher = CreateFrame("Frame", "TKDebugWatcher", UIParent)
    watcher:SetSize(1, 1)
    watcher:SetScript("OnUpdate", function(_, elapsed)
        local db = self:DB()
        local ms = elapsed * 1000
        head = head % BARS + 1
        times[head] = ms
        acc, frames, worst = acc + elapsed, frames + 1, math.max(worst, ms)
        if acc >= 0.5 then
            if db.showFrameTime then
                ft.text:SetText(string.format("%.1f ms  (%d fps)", acc / frames * 1000, math.floor(frames / acc + 0.5)))
            end
            graph.label:SetText(string.format("max %.1f ms", worst))
            acc, frames, worst = 0, 0, 0
        end
        graphWait, countersWait, mapWait, tipWait = graphWait - elapsed, countersWait - elapsed, mapWait - elapsed, tipWait - elapsed
        if db.showFrameGraph and graphWait <= 0 then
            graphWait = 0.1
            for i = 1, BARS do
                local t = times[(head + i - 1) % BARS + 1]
                local bar = graph.bars[i]
                bar:SetHeight(math.max(1, math.min(t, GRAPH_MS) / GRAPH_MS * GRAPH_H))
                if t <= 1000 / 60 + 0.5 then bar:SetColorTexture(0.4, 1, 0.4, 0.9)
                elseif t <= 1000 / 30 + 0.5 then bar:SetColorTexture(1, 0.85, 0.3, 0.9)
                else bar:SetColorTexture(1, 0.35, 0.3, 0.9) end
            end
        end
        if db.showCounters and countersWait <= 0 then
            countersWait = 0.5
            panel.counters:SetText(H:GetDebugCounters())
            self:Layout()
        end
        if db.showMapInfo and mapWait <= 0 then
            mapWait = 0.25
            panel.map:SetText(inWorld() and H:GetDebugMapInfo() or "Not in the world")
            self:Layout()
        end
        if db.inspector and tipWait <= 0 then
            tipWait = 0.1
            self:Inspect()
        end
        -- Detached Camera: the held keys move the view, 8 cells a second (24 with Shift), and so does a drag on the world
        -- view; it ends out of the world
        if H:IsDetachedCamera() then
            if not inWorld() then self:SetDetached(false) else self:Glide(elapsed); self:Drag() end
        end
    end)
    self.watcher = watcher
end

--- The panel's parts stacked under each other, as its switches show them.
function C:Layout()
    local db, p = self:DB(), self.panel
    local y, width = -PAD, 0
    local function place(region, shown, w, h)
        region:SetShown(shown)
        if not shown then return end
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, y)
        y = y - h - PAD
        width = math.max(width, w)
    end
    place(p.graph, db.showFrameGraph, BARS * BAR_W, GRAPH_H)
    place(p.counters, db.showCounters, p.counters:GetStringWidth(), p.counters:GetStringHeight())
    place(p.map, db.showMapInfo, p.map:GetStringWidth(), p.map:GetStringHeight())
    -- left of the minimap where the interface has one at the top right (it hides none of it), else under the frame time
    p:ClearAllPoints()
    local minimap = TK.Game.Minimap.Frame() -- s6-input (round 49, separation step 4b): the interface's minimap, if any
    if minimap and minimap:IsShown() then p:SetPoint("TOPRIGHT", minimap, "TOPLEFT", -6, 0)
    else p:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -8, -22) end
    p:SetShown(db.showFrameGraph or db.showCounters or db.showMapInfo)
    p:SetSize(math.max(BARS * BAR_W, width) + PAD * 2, -y)
end

function C:ApplySettings()
    local db = self:DB()
    -- Show Frame Time came from Interface > General Settings > Diagnostics (the owner, 2026-10-05: "move them here"): a
    -- profile from before carries its choice over once, and the old key goes.
    local old = TK.DB:Component("interface")
    if old and old.showFrameTime ~= nil then
        if old.showFrameTime == true then db.showFrameTime = true end
        old.showFrameTime = nil
        TK.DB:MarkDirty()
    end
    self.frame:SetShown(db.showFrameTime)
    for _, name in ipairs(MARKS) do H:SetDebugMark(name, db[name] == true) end
    if not db.inspector then self.inspector:Hide() end
    self:Layout()
    self:ApplyWeather(db)
end

-- ----- s6-effects (round 40): the Weather & Lighting tab (settings.lua) -----
-- Drawing and sound only: C#'s TK.WorldView.WeatherOverride draws the tab's choices in the server's place and never touches
-- the server's packets or sends anything (the wire's note there).

local O = CS.TK.WorldView.WeatherOverride

--- A row's share (the page's 0-100), or WeatherOverride.Natural (-1) for "As the clock has it".
local function share(v)
    v = tonumber(v) or -1
    return v < 0 and -1 or v / 100
end

--- The tab to the world view, as the game takes it (Override off: the server's, every row kept).
function C:ApplyWeather(db)
    local d = self.defaults
    O.Set(self:Applied("wxOverride", db) == true, tonumber(db.wxHour) or d.wxHour, tonumber(db.wxWeather) or d.wxWeather,
        tonumber(db.wxClouds) or d.wxClouds, share(db.wxMist), share(db.wxWind), db.wxTransitions ~= false)
end

--- The Lightning Strike (flash) and Thunder buttons.
function C:WeatherStrike(flash) O.Strike(flash == true) end

--- The Weather Front button: clear to rain, rain or snow to clear, over a Transition.
function C:WeatherFront()
    local db = self:DB()
    db.wxWeather = (tonumber(db.wxWeather) or 0) == 0 and 1 or 0
    TK.DB:MarkDirty()
    self:ApplyWeather(db)
    O.Front()
end

--- Reset to Server: every row of the tab back to its default, Override off.
function C:ResetWeather()
    local db = self:DB()
    for key, value in pairs(self.defaults) do
        if key:sub(1, 2) == "wx" then db[key] = value end
    end
    TK.DB:MarkDirty()
    self:ApplyWeather(db)
end

-- ----- the tile inspector -----

function C:Inspect()
    local tip = self.inspector
    local view = TK.GetComponent("worldview")
    local text
    if inWorld() and view and view.frame and view.frame:IsVisible() and GetMouseFocus() == view.frame then
        local ok, x, y = H:GetDebugCellAtCursor()
        if ok then text = H:DescribeDebugCell(x, y) end
    end
    if not text or text == "" then return tip:Hide() end
    tip.text:SetText(text)
    tip:SetSize(tip.text:GetStringWidth() + 18, tip.text:GetStringHeight() + 18)
    -- beside the pointer, kept on the screen
    local cx, cy = U.CursorRoot()
    local w, h = tip:GetSize()
    local x = math.min(cx + 18, GetScreenWidth() - w - 4)
    local y = math.max(cy - 18, h + 4)
    tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    tip:Show()
end

-- ----- Detached Camera -----

local MOVES = { MOVEUP = { 0, -1 }, MOVEDOWN = { 0, 1 }, MOVELEFT = { -1, 0 }, MOVERIGHT = { 1, 0 } }
local ARROWS = { UP = "MOVEUP", DOWN = "MOVEDOWN", LEFT = "MOVELEFT", RIGHT = "MOVERIGHT" }
-- the world renderer's own camera actions (3D's module.json): the view turns, tilts and zooms as its keys do; the wheel
-- zooms (round 4)
local VIEW = { Q = "orbit.left", E = "orbit.right", R = "tilt.up", F = "tilt.down", Z = "zoom.in", X = "zoom.out",
    MOUSEWHEELUP = "zoom.in", MOUSEWHEELDOWN = "zoom.out" }
local held, fast = {}, false -- each movement key held, by its key, with its direction's command
local drag -- round 4: the button held on the world view, and the pointer's last point (the view's units)

--- The pointer in the world view's own units (its tiles' units, C:TileSize's), y up.
local function pointer()
    local x, y = U.CursorRoot()
    local k = TK.GetComponent("worldview").frame:GetEffectiveScale()
    return x / k, y / k
end

--- The world renderer drawing now, by its module's name (3D's "reprojection"), or nil in Normal.
local function viewModule() return (R.Choice or ""):match("^([^:]+):") end

function C:SetDetached(on)
    if on then self:HookView() end
    H:SetDetachedCamera(on == true)
    held, drag = {}, nil
    if TK.Settings:IsOpen() then TK.Settings:RefreshPage() end
end

--- Round 4 (the owner's request: "keys or mouse"): a press on the world view while the view is detached starts a drag
--- (C:Drag). The press itself is on no map (C#'s UIHost.LiveClick, the wire's note there), so it only reaches the view's
--- frame, here.
function C:HookView()
    local view = TK.GetComponent("worldview")
    local f = view and view.frame
    if not f or f.debugCamera then return end
    f.debugCamera = true -- once per frame (the world view makes a new one when it is enabled again)
    f:HookScript("OnMouseDown", function(_, button)
        if not H:IsDetachedCamera() then return end
        local x, y = pointer()
        drag = { button = button, x = x, y = y }
    end)
    f:HookScript("OnMouseUp", function(_, button)
        if drag and drag.button == button then
            self:Drag() -- the last stretch, to the release's point
            drag = nil
        end
    end)
end

--- The held button moves the view with the pointer: the left drags the map (the view goes against the pointer, a cell for
--- each cell's width on the screen); the right turns and tilts a 3D view as its own mouse drag does, and drags the map in
--- Normal, which does not turn.
function C:Drag()
    if not drag then return end
    local x, y = pointer()
    local dx, dy = x - drag.x, y - drag.y
    if dx == 0 and dy == 0 then return end
    drag.x, drag.y = x, y
    if drag.button == "RightButton" and viewModule() then
        -- the 3D view's own drag turns by the screen's pixels
        local k = TK.UIScale() * TK.GetComponent("worldview").frame:GetEffectiveScale()
        return H:TurnDetachedCamera(dx * k, dy * k)
    end
    local tile = TK.GetComponent("worldview"):TileSize() -- a cell on the screen, in the view's units (head's r4 P3)
    H:MoveDetachedCamera(-dx / tile, dy / tile)
end

--- While the view is detached every key comes here first (core/bindings.lua): the movement keys (as bound, and the
--- arrows) and the view's keys (the wheel too: it is a key name while the keys are the UI's, InputHost.Wheel) are the
--- camera's, and every other key-down does nothing (its binding does not run: an
--- action button's key would cast); a key-up still lets go of a binding held from before. Escape is core/escape.lua's
--- (the cancel below ends it).
--- WIRE: 4a has no detached view. Its keys walk, turn and act only through the rules (UserPane::HandleKeyOrTextEvent
--- 0x005A5BD0: steps and turns through UserPane::ProcessMovement 0x005A2E00, Ctrl+arrow's 0x82, the spell and item keys),
--- which never see a key while the view is detached (C#'s Bootstrap.UiKeysNow); swallowing the other key-downs here keeps
--- a binding from acting for them (a cast, a command), and the wheel only zooms the drawing. Letting a key through while
--- detached would make the client send what the original never would; changing this changes what the server sees.
function TK.DebugKeyHook(key, down)
    if not H:IsDetachedCamera() then return false end
    fast = key:find("SHIFT-", 1, true) ~= nil
    -- the key itself: a chord ("D+DOWN": Down pressed while D is held) is its last key
    local bare = U.BareKey(key)
    bare = bare:match("%+(.+)$") or bare
    -- a held key lets go whatever it is bound to now (a profile switched while it was held)
    if not down and held[bare] then
        held[bare] = nil
        return true
    end
    local map = TK.Bindings:Map()
    -- Hint editing also works while inspecting with the camera detached. This one command only reloads local drawing
    -- hints; other bindings remain swallowed as above (4a UserPane::HandleKeyOrTextEvent 0x005A5BD0). Allowing a game
    -- action here would change what the server sees.
    if map[key] == "RELOADWORLDHINTS" then
        if down then C:ReloadWorldHints() end
        return true
    end
    local command = MOVES[map[key]] and map[key] or ARROWS[bare] or map[bare] -- a movement bound with a modifier first
    if MOVES[command] then
        held[bare] = down and command or nil
        return true
    end
    if VIEW[bare] then
        local name = viewModule()
        if down and name then R.Action(name, VIEW[bare]) end
        return true
    end
    return down
end

--- The held movement keys move the view (whole cells in Normal's view, which steps a cell at a time).
function C:Glide(elapsed)
    local dx, dy = 0, 0
    local counted = {}
    for _, command in pairs(held) do
        -- a direction counts once, however many of its keys are held (W and Up), until its last key goes up
        if not counted[command] then
            counted[command] = true
            dx, dy = dx + MOVES[command][1], dy + MOVES[command][2]
        end
    end
    if dx == 0 and dy == 0 then return end
    local speed = (fast and 24 or 8) * elapsed
    H:MoveDetachedCamera(dx * speed, dy * speed)
end

TK.Escape:AddCancel("detachedcamera", 25, function()
    if not H:IsDetachedCamera() then return false end
    C:SetDetached(false)
    return true
end)
