-- s6-interface-5x (docs/development/interfaces.md, section 1; the owner's "globally reusable interface items" at the
-- interfaces' root): what an original client's interface needs of its fixed game screen, 7.5.2's 1024 x 768 or 5.33's
-- 640 x 480: the screen scaled to fit the window and centred, the window's sides it leaves black; a panel at the place
-- the original gives its pane on that screen, followed as the window changes until the player moves it (edit mode and
-- its Layout tab); and the world view kept at the screen's map view through its own settings. 7.x's screen
-- (interfaces/7x/panels/screen) and its panels use it too (s6-interface-7x-b, round 8: the separation's step 5; they
-- had their own copy from before this file).
-- Drawing only: nothing here is sent.

local Screen = {}

--- The fit of a width x height screen in the window: its scale, and its left and top in UIParent units from the
--- window's top left; and the bars { left, bottom, width, height } of the window's parts it leaves (none where it fills
--- the window). s6-interface-7x-b (round 8, a marked edit for 7.x's screen moving onto this file): in a window of
--- w x h (UIParent units) when given, as 7.x's Letterbox(w, h) is asked for other window shapes.
function Screen.Fit(width, height, w, h)
    w, h = w or GetScreenWidth(), h or GetScreenHeight()
    local s = math.min(w / width, h / height)
    local sw, sh = width * s, height * s
    local l, b = (w - sw) / 2, (h - sh) / 2
    local bars = {}
    if l > 0.5 then
        bars[#bars + 1] = { 0, 0, l, h }
        bars[#bars + 1] = { l + sw, 0, w - l - sw, h }
    end
    if b > 0.5 then
        bars[#bars + 1] = { 0, 0, w, b }
        bars[#bars + 1] = { 0, b + sh, w, h - b - sh }
    end
    return s, l, h - (b + sh), bars
end

--- Four black bars for a screen's letterbox (frames named name .. 1-4, under the panels); Screen.Bars shows them.
function Screen.MakeBars(name)
    local out = {}
    for i = 1, 4 do
        local bar = CreateFrame("Frame", name .. i, UIParent)
        bar:SetFrameStrata("LOW")
        bar.fill = bar:CreateTexture(nil, "BACKGROUND")
        bar.fill:SetAllPoints(bar)
        bar.fill:SetColorTexture(0, 0, 0, 1)
        bar:Hide()
        out[i] = bar
    end
    return out
end

--- Shows a screen's letterbox bars over the window's parts it leaves (on), or hides them.
function Screen.Bars(bars, on, width, height)
    local _, _, _, rects = Screen.Fit(width, height)
    for i, bar in ipairs(bars) do
        local r = rects[i]
        bar:ClearAllPoints()
        if r and on then
            bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", r[1], r[2])
            bar:SetSize(r[3], r[4])
            bar:Show()
        else
            bar:Hide()
        end
    end
end

--- A panel's frame in edit mode at place (also its Layout tab's key, the profile's positions[place]), there while on()
--- says so; its default place is given at each layout (Screen.Place).
function Screen.Register(frame, place, label, on)
    return TK.EditMode:Register(frame, place, label, { "TOPLEFT", "TOPLEFT", 0, 0 }, place, on)
end

--- A registered panel at (x, y) of a width x height screen, at the screen's scale times its own (scale): its default
--- place, kept unless the player moved it (edit mode's saved place wins).
function Screen.Place(entry, width, height, x, y, scale)
    local s, l, top = Screen.Fit(width, height)
    local fs = s * (scale or 1)
    entry.frame:SetScale(fs)
    entry.default = { "TOPLEFT", "TOPLEFT", (l + x * s) / fs, -(top + y * s) / fs }
    TK.EditMode:Restore(entry)
end

--- s6-optimize (round 63): a panel component c's one frame (c.frame, registered as c.entry) at (x, y) of a width x height
--- screen (Screen.Place, at the screen's scale times its settings' own), shown in the game while its settings have it
--- on; then edit mode's movers, which follow the frames' places and the settings, not whether a frame shows. Nothing
--- before c's frame is made. The layout of every 7.x and 5.x panel with one frame. Returns whether it asked the frame to
--- show (round 64): what the panel's other frames follow, not f:IsShown(), which stays false while a plugin replaces
--- the component (core/frame.lua, a held frame keeps what is asked for until the component is given back).
function Screen.PlacePanel(c, width, height, x, y)
    local f = c.frame
    if not f then return end
    local db = c:DB()
    Screen.Place(c.entry, width, height, x, y, db.scale)
    local shown = TK.GameState:InWorld() and db.enabled == true
    f:SetShown(shown)
    TK.EditMode:UpdateMovers()
    return shown
end

--- s6-optimize (round 51): a panel component c laid out again (its method, by name: "Layout", "ApplySettings") when the
--- window's size, the UI scale or the game state (in the world or not) changes, as every panel on the scaled screen
--- follows them. Registered while its main.lua loads, so they are its listeners, withdrawn when it is turned off.
function Screen.Follow(c, method)
    local function again() c[method](c) end
    TK.On("DISPLAY_SIZE_CHANGED", again)
    TK.On("UI_SCALE_CHANGED", again)
    TK.On("TK_GAME_STATE", again)
end

--- s6-optimize (round 51): a panel's page in the settings list (core/settings.lua's node), as every 7.x and 5.x panel
--- on the screen has it: its switch and what it is on its General Settings tab, and its Layout tab (its scale and place,
--- as every panel's: edit mode moves the same; its reset is the original's place). page = { id = the page's id and its
--- place's (Screen.Register's place), title, sub = its order among its component's pages (nil: its only one), about =
--- what it is, key = its settings' table in its component's (nil: the component's own) }.
function Screen.Page(c, page)
    local key, place = page.key, page.id
    return {
        id = place, title = page.title, order = c.order, sub = page.sub,
        db = function() if key then return c:DB()[key] end return c:DB() end,
        defaults = function() if key then return c.defaults[key] end return c.defaults end,
        tabs = {
            { name = "General Settings", args = {
                { type = "toggle", key = "enabled", name = "Enabled" },
                { type = "description", name = page.about },
            } },
            { name = "Layout", args = TK.LayoutArgs(function() return place end) },
        },
    }
end

--- The world view at a rectangle { left, top, right, bottom } of a width x height screen (the original's map view):
--- that rectangle on the scaled screen, given to the shared view (TK.WorldView:PlaceAt, s6-input round 49, separation
--- step 4b: the pane's 19 x 17 cells), which keeps it there until the player moves it, and then turns db.mapPane off.
--- db: the screen component's settings (mapPane, placed).
function Screen.PlaceWorldView(db, width, height, rect)
    if not TK.WorldView then return end
    local s, l, top = Screen.Fit(width, height)
    TK.WorldView:PlaceAt({ l + rect[1] * s, top + rect[2] * s, (rect[3] - rect[1]) * s, (rect[4] - rect[2]) * s }, 19, 17, db)
end

return Screen
