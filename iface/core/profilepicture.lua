-- s6-ui-core (build 41; the owner, 2026-10-04: "add a button to the profile page to import your own from you pc with a
-- file browser and support cropping"; docs/user-related/requests/2026-10-04-profile-photo-import.md): the player's own
-- profile picture.
--   - Import opens the system's file browser on its own thread (the game goes on meanwhile), for a PNG or JPEG.
--   - The crop window shows the picture with a square on it: drag the square, size it with the slider or the mouse
--     wheel, turn the picture a quarter (a photo taken sideways), then Save or Cancel.
--   - Save keeps the square as the character's picture on this server, one a character: a new one replaces it. It is
--     shown on this client only (the player frame's portrait, the profile window) and nothing is uploaded or sent: the
--     face the original's 0x4F carries is <name>.jpf, which this never writes (LuaApi.ProfilePicture.cs).
-- This is the part every interface shares: the import, the crop window and the picture kept. Where a window shows the
-- picture with Import and Remove is its look's (the default look's profile window, Modern's and 5.x's:
-- components/dialogs/look/profilepicture.lua; step 6 of the interface separation moved it there from Modern's folder).

local H = __tk
local W = TK.UI
local U = TK.Util

local PP = {}
TK.ProfilePicture = PP

local BOX = 360       -- the crop window's picture area (the picture is fitted into it)
local MIN_SIDE = 24   -- the smallest square, in the picture's pixels

local crop            -- the crop window, made once
local state           -- the crop step: name, onDone, the picture's key and size, the square (x, y, side) and the fit

local function playerName()
    local _, name = H:GetUnitInfo("player")
    return name ~= "" and name or nil
end

--- Lays the square and the shade outside it over the fitted picture.
local function layout()
    local f, s = crop, state
    local k, px, py = s.scale, s.left, s.top
    local sl, st, ss = px + s.x * k, py + s.y * k, s.side * k
    f.square:ClearAllPoints()
    f.square:SetPoint("TOPLEFT", f.area, "TOPLEFT", sl, -st)
    f.square:SetSize(ss, ss)
    local pw, ph = s.w * k, s.h * k
    local bands = {
        { px, py, pw, st - py },                    -- above
        { px, st + ss, pw, py + ph - st - ss },     -- below
        { px, st, sl - px, ss },                    -- left
        { sl + ss, st, px + pw - sl - ss, ss },     -- right
    }
    for i, b in ipairs(bands) do
        local t = f.shade[i]
        t:SetShown(b[3] > 0.5 and b[4] > 0.5)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", f.area, "TOPLEFT", b[1], -b[2])
        t:SetSize(math.max(1, b[3]), math.max(1, b[4]))
    end
end

local function maxSide() return math.min(state.w, state.h) end

--- The square at a side (clamped), around its centre, and the slider following it.
local function resize(side)
    local s = state
    local cx, cy = s.x + s.side / 2, s.y + s.side / 2
    s.side = U.Clamp(side, math.min(MIN_SIDE, maxSide()), maxSide())
    s.x = U.Clamp(cx - s.side / 2, 0, s.w - s.side)
    s.y = U.Clamp(cy - s.side / 2, 0, s.h - s.side)
    local span = maxSide() - math.min(MIN_SIDE, maxSide())
    crop.size:SetValue(span > 0 and math.floor((s.side - math.min(MIN_SIDE, maxSide())) / span * 100 + 0.5) or 100)
    layout()
end

--- The crop step's picture (just opened or turned): fitted into the area, the square its largest one, centred.
local function showPicture(key, w, h)
    local s = state
    s.key, s.w, s.h = key, w, h
    s.scale = math.min(BOX / w, BOX / h)
    s.left, s.top = (BOX - w * s.scale) / 2, (BOX - h * s.scale) / 2
    crop.picture:SetTexture(key)
    crop.picture:ClearAllPoints()
    crop.picture:SetPoint("TOPLEFT", crop.area, "TOPLEFT", s.left, -s.top)
    crop.picture:SetSize(w * s.scale, h * s.scale)
    s.side = maxSide()
    s.x, s.y = (w - s.side) / 2, (h - s.side) / 2
    resize(s.side)
end

local function build()
    local f = W.Window("TKProfilePictureCrop", "Crop Your Picture", BOX + 40, BOX + 168)
    f:SetFrameStrata("FULLSCREEN_DIALOG")   -- over the profile window that opened it
    f.area = CreateFrame("Frame", nil, f)
    f.area:SetSize(BOX, BOX)
    f.area:SetPoint("TOP", f, "TOP", 0, -40)
    f.area:SetBackdrop({ bg = { 0.03, 0.03, 0.04, 1 }, edge = W.innerEdge, bgFile = "tk:white" })
    f.picture = f.area:CreateTexture(nil, "ARTWORK")
    f.shade = {}
    for i = 1, 4 do
        f.shade[i] = f.area:CreateTexture(nil, "OVERLAY")
        f.shade[i]:SetColorTexture(0, 0, 0, 0.6)
    end
    -- The square: dragged by the left button (as a window is), sized by the wheel over the area.
    f.square = CreateFrame("Frame", "TKProfilePictureSquare", f.area)
    f.square:SetBackdrop({ bg = { 0, 0, 0, 0 }, edge = { W.gold[1], W.gold[2], W.gold[3], 1 }, edgeFile = "tk:edge" })
    f.square:EnableMouse(true)
    f.square:RegisterForDrag("LeftButton")
    -- The press is where the drag is measured from (the drag starts a few pixels later), so the square stays under the
    -- pointer; k is the root's units a picture pixel.
    f.square:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not state then return end
        local cx, cy = U.CursorRoot()
        local _, _, rw = U.RootRect(f.area)
        self.from = { cx = cx, cy = cy, x = state.x, y = state.y, k = state.scale * rw / BOX }
    end)
    f.square:SetScript("OnDragStart", function(self)
        if not self.from then return end
        self:SetScript("OnUpdate", function()
            local s, from = state, self.from
            if not s or not from then return end
            local nx, ny = U.CursorRoot()
            s.x = U.Clamp(from.x + (nx - from.cx) / from.k, 0, s.w - s.side)
            s.y = U.Clamp(from.y - (ny - from.cy) / from.k, 0, s.h - s.side)   -- the root's y grows upwards
            layout()
        end)
    end)
    f.square:SetScript("OnDragStop", function(self)
        self.from = nil
        self:SetScript("OnUpdate", nil)
    end)
    f.area:EnableMouseWheel(true)
    f.area:SetScript("OnMouseWheel", function(_, delta)
        if state then resize(state.side * (delta > 0 and 1.1 or 1 / 1.1)) end
    end)
    -- How to use it, as the square's tooltip (the next round; the owner: short text on the window, explanations in a tooltip)
    W.Tip(f.square, "Drag to move. The wheel or the slider sizes it.")
    f.size = W.Slider(f, "Size", 0, 100, 1, BOX - 120, function(v)
        local lo = math.min(MIN_SIDE, maxSide())
        resize(lo + (maxSide() - lo) * v / 100)
    end)
    f.size:SetPoint("TOP", f.area, "BOTTOM", 0, -14)
    f.status = W.Label(f, "", 11, { 1, 0.4, 0.3 })
    f.status:SetPoint("TOP", f.size, "BOTTOM", 0, -2)
    f.turn = W.Button(f, "Turn", 90, 22, nil, function()
        local key, w, h = H:ProfilePictureTurn()
        if key ~= "" then showPicture(key, w, h) end
    end)
    f.save = W.Button(f, "Save", 90, 22, nil, function() PP:Save() end)
    f.cancel = W.Button(f, "Cancel", 90, 22, nil, function() f:Hide() end)
    f.save:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
    f.turn:SetPoint("RIGHT", f.save, "LEFT", -10, 0)
    f.cancel:SetPoint("LEFT", f.save, "RIGHT", 10, 0)
    -- Closed any way but Save (Cancel, its close box, Escape, leaving the world): the crop step's picture goes.
    f:SetScript("OnHide", function()
        if state then
            state = nil
            H:ProfilePictureClose()
        end
    end)
    return f
end

--- Opens a picture file in the crop window for name's picture; onDone(true) after a Save. False (and the reason shown)
--- when it cannot be opened.
function PP:Open(name, path, onDone)
    local key, w, h, problem = H:ProfilePictureOpen(path)
    if key == "" then
        TK.Popup("The picture could not be opened: " .. tostring(problem) .. ".", "Import Picture")
        return false
    end
    crop = crop or build()
    state = { name = name, onDone = onDone }
    crop.status:SetText("")
    showPicture(key, w, h)
    crop:Show()   -- shown last, on top (W.Window)
    TK.FitToScreen(crop, 10)
    return true
end

--- Import: the system's file browser for a picture, then the crop window (nothing when it is cancelled). One browser at
--- a time. (After build 41, s6-optimize's audit: the shared dialog job and TK.Await, core/await.lua.)
function PP:Import(name, onDone)
    if not name or PP.browsing then return end
    PP.browsing = true
    local job = H:ProfilePictureBrowse()
    TK.Await(function() return H:JobAnswer(job) end, function(path)
        PP.browsing = false
        if path ~= "" and TK.GameState:InWorld() then PP:Open(name, path, onDone) end
    end)
end

--- Save: the square kept as the character's picture. TK_PROFILE_PICTURE_SAVED tells whoever shows it (the player frame
--- turns its "Use my profile image as my portrait" on: s6-optimize's audit, core no longer writes a component's setting).
function PP:Save()
    local s = state
    if not s then return end
    local ok, problem = H:ProfilePictureSave(s.name, s.x, s.y, s.side)
    if not ok then
        crop.status:SetText("Not saved: " .. tostring(problem) .. ".")
        return
    end
    state = nil
    crop:Hide()
    TK.FireEvent("TK_PROFILE_PICTURE_SAVED", s.name)
    if s.onDone then s.onDone(true) end
end

--- Whether the crop window shows (the tests and the live check read it).
function PP:Cropping() return crop ~= nil and crop:IsShown() end

--- The crop window and its state, for the tests and the live check: the frame, and the square in the picture's pixels.
function PP:CropWindow() return crop, state end

-- ----- for a look's own panel (the default look's: components/dialogs/look/profilepicture.lua) -----

--- Whether a picture can be imported now (a player in the world, whose name it is kept under).
function PP:CanImport() return playerName() ~= nil end

--- The player's own picture's texture key, "" when there is none: the picture the player imported, never the .jpf the
--- original sends.
function PP:Current()
    local name = playerName()
    return name and H:GetOwnProfilePicture(name) or ""
end

--- Import for the player: the browser, then the crop window; onDone(true) after a Save.
function PP:ImportForPlayer(onDone) PP:Import(playerName(), onDone) end

--- Removes the player's picture (its file and its texture).
function PP:Remove() H:ProfilePictureRemove(playerName() or "") end
