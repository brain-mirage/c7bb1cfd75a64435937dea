-- The original's art from the exporter's packs (C#: PackArt): item icons by their number (the ITEM.EPF frame the
-- server names for an item) and interface images by file and frame. Every function returns nil without the packs,
-- and callers keep their placeholder art then. The original has no spell icons (its spell list shows the key letter
-- and the name: NewSpellInventoryPane::OnPaint), so spells keep the lettered squares.

local H = __tk

local A = {}
TK.Art = A

function A.Available() return H:ArtAvailable() end

--- Head note 47: what the login screen and the live world view say without the packs (the placeholder world is the
--- offline mode's only).
A.NO_PACKS_TEXT = "No art packs found: the world can't be drawn. Put the pack set in data\\packs or start with --packs <folder>."

local function sized(key)
    local ok, w, h = H:GetArtSize(key)
    if ok then return key, w, h end
end

--- Item icon n: its texture key and size in pixels, or nil. A supplied colour uses
--- the existing item renderer and live palette cycling for native inventory/equipment
--- (4a ScreenPane timer 1, 0x00556D50). Dialogs keep A.Item's requested phase.
function A.Icon(n, colour)
    if type(n) ~= "number" or n < 0 then return nil end
    if colour and colour ~= 0 then
        local key, w, h = H:GetItemIconPicture((math.floor(n) + 0xC000) % 0x10000, colour)
        if key and key ~= "" then return key, w, h end
    end
    return sized("art:icon/" .. math.floor(n))
end

--- s6-interface-7x (round 2): an item's picture by the server's picture number (0xC000-biased, as 0x0F and the dialogs
--- name it) and its colour byte: a dyed one as the ground draws it (H:GetItemPicture: ITEM.TBL's palette, the SUPER
--- palette colour >> 5, the shade; 4a's ItemObjImageLib, its frame rectangle's size), an undyed one (colour 0, or no
--- drawing yet) its icon (A.Icon). Key and size, or nil.
--- s6-characters (round 43): a dialog's picture, as it is the dialogs that draw by it: an item whose colours cycle shows
--- the cycling step it is drawn at, and changes only when the dialog draws it again (4a repaints a dialog when something
--- of its own invalidates it; only the side panel's tab and the map every 500 ms). The bags, bars and equipment draw by
--- A.Icon, which keeps cycling.
function A.Item(picture, colour)
    if type(picture) ~= "number" or picture < 0 then return nil end
    if colour and colour ~= 0 then
        local key, w, h = H:GetItemPicture(picture, colour)
        if key and key ~= "" then return key, w, h end
    end
    local key = A.Icon((picture + 0x4000) % 0x10000)
    if not key then return nil end
    return sized(H:GetArtStill(key))
end

--- Frame n of an interface image (for example "DEADSIGN.EPF"), drawn with the given palette: key and size, or nil.
function A.Image(file, frame, palette)
    return sized("art:image/" .. file:lower() .. "/" .. (frame or 0) .. (palette and ("@" .. palette) or ""))
end

--- s6-modular-g (interfaces, 7.x's skin): glyph n of 9X11FONT.BIN (the original's digits), drawn with the given
--- palette: key and size, or nil.
function A.Digit(n, palette)
    return sized("art:digits/" .. math.floor(n) .. (palette and ("@" .. palette) or ""))
end

--- s6-modular-g (interfaces, 7.x's screen): where a key's picture starts in its frame (the textures are cropped
--- to their drawn pixels), so a picture put where the original puts the frame lands on the original's pixels; 0, 0
--- without it.
function A.Origin(key)
    local ok, x, y = H:GetArtOrigin(key)
    if ok then return x, y end
    return 0, 0
end

--- The source frame's canvas rectangle (left, top, width, height), including an empty animation step.
--- Unlike Origin's mask crop, this supplies the placement of a frame that moves within its sprite set.
function A.FrameRect(key)
    local ok, l, t, w, h = H:GetArtFrameRect(key)
    if ok then return l, t, w, h end
end

--- Shows art in a texture, centred on anchor at its own pixel size when it fits in a box of size box (sharp pixel
--- art at UI scale 1), shrunk to fit when it does not.
function A.Place(tex, anchor, key, w, h, box)
    local s = math.min(1, box / math.max(w, h, 1))
    tex:SetTexture(key)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:ClearAllPoints()
    tex:SetSize(w * s, h * s)
    tex:SetPoint("CENTER", anchor, "CENTER", 0, 0)
end
