-- The Library pages' pictures (s6-library-pages), behind one function. They come from s6-spell-icons' catalogue of the
-- packs' pictures (lua/core/artsource.lua, the picture viewer's sources): a monster or NPC is its "creature" picture,
-- standing facing south as the map draws it (__tk:GetArtPicture; still since s6-library round 25, the owner's "static
-- graphic"), and an item its "icon", the ITEM.EPF frame the bag and the Character tab draw. A character's look, which is
-- no family, is drawn as the dialogs draw a human (GetObjectImage's tag 0, its 43 status bytes). Drawing only: nothing
-- is sent.

local H = __tk

local P = {}
TK.LibraryPictures = P

local SOUTH = 2 -- the catalogue's facings: 0 north, 1 east, 2 south, 3 west

--- The bytes of a hex string.
local function bytes(hex)
    return (hex:gsub("%x%x", function(b) return string.char(tonumber(b, 16)) end))
end

--- A picture: key, width and height, or nil when there is none (no art packs, or no look). kind "creature" (a, b: its
--- picture and colour, the Library's look; the catalogue's still frame), "item" (a: its 0x0F picture, the server's
--- number), "look" (a: a character's 43 status bytes in hex, centred in a clear pane of width x height, default 96 x 96).
function P.Picture(kind, a, b, width, height)
    local key, w, h
    if kind == "item" then
        -- The server's item number is 0xC000 and up; ITEM.EPF's frame is 0x4000 on (as the Character tab draws it).
        key, w, h = TK.Art.Icon((a + 0x4000) % 0x10000)
    elseif kind == "creature" then
        key, w, h = H:GetArtPicture("creature", a, { facing = SOUTH, colour = b })
    elseif kind == "look" and type(a) == "string" and #a == 86 then
        -- s6-library round 25 (the live check: a stealthed character's Overview was empty): standing (posture 0), as the
        -- fitting room forces it (PaneFigures.FittingRoomBase; the Character window draws the session's posture), so a
        -- look recorded invisible (posture 2), translucent, a ghost or mounted still shows the character and its gear.
        key, w, h = H:GetObjectImage("\0" .. bytes(a:sub(1, 2) .. "00" .. a:sub(5)), width or 96, height or 96, true)
    end
    if key and key ~= "" then return key, w, h end
end

--- A picture shown in a texture, centred in anchor at whole-number scale up to fit a box of size box (pixel art stays
--- sharp); hidden when there is none. Returns whether one shows.
function P.Show(texture, anchor, box, kind, a, b, width, height)
    local key, w, h = P.Picture(kind, a, b, width, height)
    if not key then
        texture:Hide()
        return false
    end
    local scale = math.max(1, math.floor(box / math.max(w, h, 1)))
    if w * scale > box or h * scale > box then scale = box / math.max(w, h) end
    texture:SetTexture(key)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:ClearAllPoints()
    texture:SetSize(w * scale, h * scale)
    texture:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    texture:Show()
    return true
end
