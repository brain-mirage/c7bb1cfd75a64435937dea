-- A picture viewer (s6-spell-icons; the owner, 2026-10-04: "make sure that this viewer is modular, we may want to reuse
-- this interface as a general in program model viewer"): a scrolling grid of pictures, and once one is clicked a detail
-- part beside it with a larger preview, which plays an animation, the frame controls that trim it and, for a source with
-- facings or several animations, a facing control and an animation control. It knows nothing of what it shows. The API
-- (DESIGN.md of s6-spell-icons, section 6, keeps it written down for other windows; keep it stable, and add to it only):
--
--   local v = TK.UI.PictureViewer(parent, width, height, { name = "TKMyViewer", cell = 40, detailWidth = 200 })
--   v:SetSource(src, emptyText)   the pictures; the grid from its top, the detail closed
--   v:Select(i)                   marks picture i (nil: none), scrolled into view
--   v:Open(i) / v:Close()         the detail part for picture i, as a click opens it / closed
--   v:SetRange(first, last)       the opened animation's played frames (-1: its first, its last)
--   v:SetFacing(f)                the opened picture's facing (0 .. src.facings - 1)
--   v:SetAnimation(id)            the opened picture's animation (nil: its first, the default) (round 3)
--   v:Refresh()                   draws the visible cells again (the pictures changed)
--   v.onPick(i)                   a picture clicked (the detail has opened on it)
--   v.onRange(first, last, frames)   a frame control used
--   v.onFacing(f)                 the facing control used
--   v.onAnimation(id, isDefault)  the animation control used (round 3); isDefault: the picture's first
--   v.detail.extra                a frame below the controls for the host's own (the spell editor's check box)
--
-- A source (TK.UI.ArtSource in core/artsource.lua makes them for the packs' pictures):
--
--   src.count()                       how many pictures there are
--   src.picture(i, facing, animation) picture i (from 1): key, width, height, label (its tooltip), frames (0 or 1: a
--                                     still picture, no frame controls), text (optional: drawn over it, as a lettered
--                                     button's letter). facing and animation: nil in the grid (the source's own), the
--                                     detail's there
--   src.now(i, first, last, facing, animation)   optional, for animations: the key, width and height of the frame
--                                     showing now, playing first..last (from 0) again and again; asked each frame while
--                                     the detail shows it
--   src.facings, src.facingNames      optional: how many facings (4 for a creature) and their names, from 0
--   src.animations(i, facing)         optional (round 3): picture i's animations in a facing, a list of { id, name }
--                                     (a creature's Walk, Stand, Attack...); the control shows with two or more
--
-- Cells are made for the visible rows only and reused as the grid scrolls, so a source may hold thousands.

local W = TK.UI

local CELL, DETAIL_W, BAR_W = 40, 200, 8
local DEFAULT_FACING = 2 -- south, facing the viewer, as the panes draw figures

--- One row of controls: "Start  [<] 4 [>]" (s6-ui-core round 62: the shared stepper, W.Stepper), as wide as the detail's.
local function stepRow(parent, label, onStep)
    local row = W.Stepper(parent, label, onStep, { valueWidth = 48 })
    row:SetWidth(DETAIL_W - 16)
    return row
end

--- A viewer in parent, width x height. opts: name (a global name; its cells are name .. "Cell" .. n), cell (the grid's
--- cell size), detailWidth.
function W.PictureViewer(parent, width, height, opts)
    opts = opts or {}
    local cell = opts.cell or CELL
    local detailW = opts.detailWidth or DETAIL_W
    local v = CreateFrame("Frame", opts.name, parent)
    v:SetSize(width, height)
    v.cells, v.top, v.selected, v.opened = {}, 0, nil, nil
    v.facing, v.frames = DEFAULT_FACING, 0
    v.src = { count = function() return 0 end }

    -- ----- the grid and its scroll bar -----
    v.grid = CreateFrame("Frame", opts.name and (opts.name .. "Grid") or nil, v)
    v.grid:SetPoint("TOPLEFT", v, "TOPLEFT", 0, 0)
    v.grid:EnableMouseWheel(true)
    v.grid:SetScript("OnMouseWheel", function(_, delta) v:Scroll(delta > 0 and -1 or 1) end)
    v.track = CreateFrame("Frame", nil, v)
    v.track:SetWidth(6)
    local trackTex = v.track:CreateTexture(nil, "BACKGROUND")
    trackTex:SetAllPoints(v.track)
    trackTex:SetColorTexture(1, 1, 1, 0.06)
    v.thumb = CreateFrame("Button", nil, v.track)
    v.thumb:SetWidth(6)
    local thumbTex = v.thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints(v.thumb)
    thumbTex:SetColorTexture(0.8, 0.7, 0.4, 0.6)
    v.thumb:RegisterForDrag("LeftButton")
    local drag
    v.thumb:SetScript("OnDragStart", function()
        local _, y = TK.Util.CursorRoot()
        drag = { y = y, top = v.top }
        v.thumb:SetScript("OnUpdate", function()
            local _, cy = TK.Util.CursorRoot()
            local free = v.track:GetHeight() - v.thumb:GetHeight()
            if free <= 0 then return end
            v:ScrollTo(drag.top + math.floor((drag.y - cy) / free * v:MaxTop() + 0.5))
        end)
    end)
    v.thumb:SetScript("OnDragStop", function()
        v.thumb:SetScript("OnUpdate", nil)
        drag = nil
    end)
    v.empty = W.Label(v.grid, "", 12, { 0.7, 0.7, 0.7 })
    v.empty:SetPoint("TOP", v.grid, "TOP", 0, -20)

    -- ----- the detail part: the preview, the frame and facing controls, the host's own -----
    local d = W.Panel(v, nil, true)
    v.detail = d
    d:SetWidth(detailW)
    d:SetPoint("TOPRIGHT", v, "TOPRIGHT", 0, 0)
    d:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", 0, 0)
    d.box = CreateFrame("Frame", nil, d)
    d.box:SetSize(detailW - 40, detailW - 40)
    d.box:SetPoint("TOP", d, "TOP", 0, -12)
    local boxBg = d.box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints(d.box)
    boxBg:SetColorTexture(0, 0, 0, 0.5)
    d.preview = d.box:CreateTexture(nil, "ARTWORK")
    d.text = d.box:CreateFontString(nil, "OVERLAY")
    d.text:SetFont(40, "OUTLINE")
    d.text:SetPoint("CENTER", d.box, "CENTER", 0, 0)
    d.label = W.Label(d, "", 12, W.white)
    d.label:SetWidth(detailW - 16)
    d.label:SetPoint("TOP", d.box, "BOTTOM", 0, -6)
    -- The facing, for a source with facings (a creature's four), and the animation, for a picture with several (round 3:
    -- a creature's walk, stand, attack...); placed as each picture needs (ShowOpened).
    d.facing = stepRow(d, "Facing", function(step) v:StepFacing(step) end)
    d.facing:SetPoint("TOP", d.label, "BOTTOM", 0, -8)
    d.animation = stepRow(d, "Action", function(step) v:StepAnimation(step) end)
    d.controls = CreateFrame("Frame", nil, d)
    d.controls:SetSize(detailW - 16, 70)
    -- The owner's controls: Start's ">" starts the animation further in, End's "<" ends it sooner (a 16-frame zap played
    -- from 4 to 12); the other two buttons undo them.
    d.start = stepRow(d.controls, "Start", function(step) v:Step("first", step) end)
    d.start:SetPoint("TOPLEFT", d.controls, "TOPLEFT", 0, 0)
    d.finish = stepRow(d.controls, "End", function(step) v:Step("last", step) end)
    d.finish:SetPoint("TOPLEFT", d.start, "BOTTOMLEFT", 0, -4)
    d.frames = W.Label(d.controls, "", 11, { 0.7, 0.7, 0.7 }, "LEFT")
    d.frames:SetPoint("TOPLEFT", d.finish, "BOTTOMLEFT", 0, -6)
    d.extra = CreateFrame("Frame", nil, d)
    d.extra:SetSize(detailW - 16, 60)
    d.extra:SetPoint("TOP", d.controls, "BOTTOM", 0, -6)
    d:Hide()
    -- The animation plays while the detail shows it (the source's frame showing now).
    d:SetScript("OnUpdate", function()
        if v.opened and v.frames > 1 and v.src.now then
            v:ShowPreview(v.src.now(v.opened, v.first, v.last, v:Facing(), v.animation))
        end
    end)

    --- Columns and rows that fit the grid now (narrower while the detail shows).
    function v:Layout()
        local gridW = width - BAR_W - (d:IsShown() and detailW + 8 or 0)
        self.cols = math.max(1, math.floor(gridW / cell))
        self.rows = math.max(1, math.floor(height / cell))
        self.grid:SetSize(self.cols * cell, height)
        self.track:ClearAllPoints()
        self.track:SetPoint("TOPLEFT", self.grid, "TOPRIGHT", 2, 0)
        self.track:SetPoint("BOTTOMLEFT", self.grid, "BOTTOMRIGHT", 2, 0)
        for i = #self.cells + 1, self.cols * self.rows do
            local b = CreateFrame("Button", opts.name and (opts.name .. "Cell" .. i) or nil, self.grid)
            b:SetSize(cell - 2, cell - 2)
            -- s6-ui-core (round 62): the shared slot's picture, its edge the chosen mark (gold), the light
            local _
            _, b.tex, b.sel = W.SlotArt(b, { edge = W.gold })
            b.text = b:CreateFontString(nil, "OVERLAY")
            b.text:SetFont(16, "OUTLINE")
            b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
            b:SetScript("OnClick", function(self)
                -- The picture under the pointer, taken once: opening the detail lays the grid out again (fewer columns)
                -- and scrolls it, after which this cell may show another picture or none (Astra's review of round 1).
                local i = self.index
                if not i then return end
                v:Open(i)
                if v.onPick then v.onPick(i) end
            end)
            b:SetScript("OnEnter", function(self)
                if not self.label or self.label == "" then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(self.label, 1, 1, 1)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            self.cells[i] = b
        end
        for i, b in ipairs(self.cells) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.grid, "TOPLEFT", (i - 1) % self.cols * cell, -math.floor((i - 1) / self.cols) * cell)
        end
        self:ScrollTo(self.top)
    end

    function v:MaxTop() return math.max(0, math.ceil(self.src.count() / self.cols) - self.rows) end

    function v:Scroll(rows) self:ScrollTo(self.top + rows) end

    --- Shows the grid from row `top` (from 0).
    function v:ScrollTo(top)
        self.top = math.max(0, math.min(self:MaxTop(), top or 0))
        self:Refresh()
    end

    --- Draws the visible cells and the scroll bar again (the pictures may have changed).
    function v:Refresh()
        local n = self.src.count()
        local visible = self.cols * self.rows
        for i, b in ipairs(self.cells) do
            local index = self.top * self.cols + i
            local shown = i <= visible and index <= n
            b.index = shown and index or nil
            b:SetShown(shown)
            if shown then
                local key, w, h, label, _, text = self.src.picture(index)
                b.label = label
                if key and key ~= "" then
                    TK.Art.Place(b.tex, b, key, w or cell, h or cell, cell - 6)
                    b.tex:Show()
                else
                    b.tex:Hide()
                end
                b.text:SetText(text or "")
                b.sel:SetShown(index == self.selected)
            end
        end
        local maxTop = self:MaxTop()
        self.track:SetShown(maxTop > 0)
        if maxTop > 0 then
            local h = self.track:GetHeight()
            local th = math.max(16, h * self.rows / (self.rows + maxTop))
            self.thumb:SetHeight(th)
            self.thumb:ClearAllPoints()
            self.thumb:SetPoint("TOP", self.track, "TOP", 0, -(h - th) * self.top / maxTop)
        end
    end

    --- A new source: the grid from its top, the detail closed. empty: what the grid says when the source has nothing.
    function v:SetSource(src, empty)
        self.src = src
        self.selected, self.opened = nil, nil
        self.empty:SetText(empty or "")
        self.empty:SetShown(src.count() == 0)
        d:Hide()
        self.top = 0
        self:Layout()
    end

    --- Marks picture i as the chosen one (nil: none), scrolled into view.
    function v:Select(i)
        self.selected = i
        if i and self.cols then
            local row = math.floor((i - 1) / self.cols)
            if row < self.top or row >= self.top + self.rows then self.top = row end
        end
        self:ScrollTo(self.top)
    end

    --- The facing the detail shows (nil for a source without facings).
    function v:Facing() return self.src.facings and self.facing or nil end

    --- The detail part for picture i: expanded beside the grid, facing south in its first animation, its frame controls
    --- for an animation only.
    function v:Open(i)
        self.selected, self.opened, self.facing, self.animation = i, i, DEFAULT_FACING, nil
        local wasShown = d:IsShown()
        d:Show()
        if not wasShown then self:Layout() end
        d.facing:SetShown(self.src.facings ~= nil)
        self:ShowOpened()
        self:Select(i)
    end

    --- The opened picture's animation in the list (1: the first, the default).
    function v:AnimationIndex()
        for k, a in ipairs(self.animations or {}) do
            if a.id == self.animation then return k end
        end
        return 1
    end

    --- The opened picture in its facing and animation: its preview, label and frame count (the whole animation played).
    function v:ShowOpened()
        -- Its animations in this facing; one it does not have there gives way to the first.
        self.animations = self.src.animations and self.src.animations(self.opened, self:Facing()) or {}
        local found = false
        for _, a in ipairs(self.animations) do found = found or a.id == self.animation end
        if not found then self.animation = nil end
        local many = #self.animations > 1
        local above = self.src.facings and d.facing or d.label
        d.animation:SetShown(many)
        d.animation:ClearAllPoints()
        d.animation:SetPoint("TOP", above, "BOTTOM", 0, -4)
        d.controls:ClearAllPoints()
        d.controls:SetPoint("TOP", many and d.animation or above, "BOTTOM", 0, -8)
        local key, w, h, label, frames, text = self.src.picture(self.opened, self:Facing(), self.animation)
        self.frames = frames or 0
        self.first, self.last = 0, math.max(0, self.frames - 1)
        d.label:SetText(label or "")
        d.text:SetText(text or "")
        self:ShowPreview(key, w, h)
        d.controls:SetShown(self.frames > 1)
        self:UpdateControls()
    end

    --- Closes the detail part; the grid takes the whole width again.
    function v:Close()
        self.opened = nil
        d:Hide()
        self:Layout()
    end

    function v:ShowPreview(key, w, h)
        if key and key ~= "" then
            -- Drawn up to twice its size in the box, whole steps only (sharp pixel art).
            local box = d.box:GetWidth()
            local s = math.max(1, math.min(2, math.floor(box / math.max(w or 1, h or 1, 1))))
            TK.Art.Place(d.preview, d.box, key, (w or box) * s, (h or box) * s, box)
            d.preview:Show()
        else
            d.preview:Hide()
        end
    end

    --- The played range of the opened animation (-1 or out of range: its first or last frame).
    function v:SetRange(first, last)
        local n = self.frames or 0
        self.first = (first and first >= 0 and first < n) and first or 0
        self.last = (last and last >= 0 and last < n) and last or math.max(0, n - 1)
        if self.first > self.last then self.first, self.last = 0, math.max(0, n - 1) end
        self:UpdateControls()
    end

    --- The opened picture's facing; its frames are read again (another facing may have another number of them).
    function v:SetFacing(f)
        local n = self.src.facings
        if not n or not self.opened then return end
        f = (f and f >= 0 and f < n) and f or DEFAULT_FACING
        if f == self.facing then return end
        self.facing = f
        self:ShowOpened()
    end

    function v:StepFacing(step)
        local n = self.src.facings
        if not n or not self.opened then return end
        self.facing = (self.facing + step) % n
        self:ShowOpened()
        if self.onFacing then self.onFacing(self.facing) end
    end

    --- The opened picture's animation (nil: its first); its frames are read again.
    function v:SetAnimation(id)
        if not self.opened or id == self.animation then return end
        self.animation = id
        self:ShowOpened()
    end

    function v:StepAnimation(step)
        local list = self.animations or {}
        if #list < 2 then return end
        local k = (self:AnimationIndex() - 1 + step) % #list + 1
        self.animation = list[k].id
        self:ShowOpened()
        if self.onAnimation then self.onAnimation(self.animation, k == 1) end
    end

    function v:Step(which, step)
        if which == "first" then
            self.first = math.max(0, math.min(self.last, self.first + step))
        else
            self.last = math.max(self.first, math.min(self.frames - 1, self.last + step))
        end
        self:UpdateControls()
        if self.onRange then self.onRange(self.first, self.last, self.frames) end
    end

    function v:UpdateControls()
        d.start.value:SetText(tostring(self.first or 0))
        d.finish.value:SetText(tostring(self.last or 0))
        d.start.back:SetEnabled((self.first or 0) > 0)
        d.start.forward:SetEnabled((self.first or 0) < (self.last or 0))
        d.finish.back:SetEnabled((self.last or 0) > (self.first or 0))
        d.finish.forward:SetEnabled((self.last or 0) < (self.frames or 0) - 1)
        d.frames:SetText(string.format("Frames %d-%d of %d", self.first or 0, self.last or 0, self.frames or 0))
        local names = self.src.facingNames
        d.facing.value:SetText(names and names[self.facing] or tostring(self.facing))
        local a = self.animations and self.animations[self:AnimationIndex()]
        d.animation.value:SetText(a and (a.name or a.id) or "")
    end

    v:Layout()
    return v
end
