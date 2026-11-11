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
-- shared/components/dialogs/look/profilepicture.lua; step 6 of the interface separation moved it there from Modern's folder).

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

--- One shade band (its left, top, width and height over the area, y down).
local function band(f, t, x, y, w, h)
    t:SetShown(w > 0.5 and h > 0.5)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", f.area, "TOPLEFT", x, -y)
    t:SetSize(math.max(1, w), math.max(1, h))
end

--- Lays the square and the shade outside it over the fitted picture. The drag asks every frame, so the last geometry is
--- kept in crop.laid and nothing is set when it is unchanged (only the square and the shade move with it).
local function layout()
    local f, s = crop, state
    local k, px, py = s.scale, s.left, s.top
    local sl, st, ss = px + s.x * k, py + s.y * k, s.side * k
    local pw, ph = s.w * k, s.h * k
    local laid = f.laid or {}
    f.laid = laid
    if laid[1] == sl and laid[2] == st and laid[3] == ss and laid[4] == px and laid[5] == py and laid[6] == pw and laid[7] == ph then
        return
    end
    laid[1], laid[2], laid[3], laid[4], laid[5], laid[6], laid[7] = sl, st, ss, px, py, pw, ph
    f.square:ClearAllPoints()
    f.square:SetPoint("TOPLEFT", f.area, "TOPLEFT", sl, -st)
    f.square:SetSize(ss, ss)
    band(f, f.shade[1], px, py, pw, st - py)                 -- above
    band(f, f.shade[2], px, st + ss, pw, py + ph - st - ss)  -- below
    band(f, f.shade[3], px, st, sl - px, ss)                 -- left
    band(f, f.shade[4], sl + ss, st, px + pw - sl - ss, ss)  -- right
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

--- s6-ui-core (round 131, piece 6b of the Global Interface's C# shell): the window and its fixed parts are the shell's
--- (Runtime/Shell/ProfilePictureCrop.cs: on the FULLSCREEN_DIALOG strata, over the profile window that opened it),
--- wrapped under the names the tests and the live check use. What they do stays here.
local function build()
    local function part(name) return TK.Wrap(H:ShellToolPart("crop", name)) end
    local function button(name) return TK.WrapShellButton(H:ShellToolPart("crop", name)) end
    local f = W.ShellWindow(part("frame"), part("fill"), part("band"))
    f.title, f.close = part("title"), button("close")
    f.area, f.picture = part("area"), part("picture")
    f.shade = { part("shade1"), part("shade2"), part("shade3"), part("shade4") }
    -- The square: dragged by the left button (as a window is), sized by the wheel over the area.
    f.square = part("square")
    -- the names CreateFrame gave the Lua window: its globals and GetName (as the map window's, round 130)
    f.__name, f.square.__name = "TKProfilePictureCrop", "TKProfilePictureSquare"
    _G.TKProfilePictureCrop, _G.TKProfilePictureSquare = f, f.square
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
    f.status = part("status")
    f.status:SetPoint("TOP", f.size, "BOTTOM", 0, -2)
    f.turn, f.save, f.cancel = button("turn"), button("save"), button("cancel")
    f.turn:SetScript("OnClick", function()
        local key, w, h = H:ProfilePictureTurn()
        if key ~= "" then showPicture(key, w, h) end
    end)
    f.save:SetScript("OnClick", function() PP:Save() end)
    f.cancel:SetScript("OnClick", function() f:Hide() end)
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
    crop:Show()   -- shown last, on top (a toplevel window: TK.Escape's)
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

-- ----- for a look's own panel (the default look's: shared/components/dialogs/look/profilepicture.lua) -----

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
