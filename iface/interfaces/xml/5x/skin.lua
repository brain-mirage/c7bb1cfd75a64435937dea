-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md): what 5.x's panels and dialogs
-- draw with. Its pictures are NexusTK 5.33's own, from its interface archive NInt.dat: the exporter packs it, read in
-- place, into the set beside the base set ("ntkx interface"; PackArt's "art:533/<FILE>/<frame>@<PALETTE>" keys), never
-- committed. Its text is 5.33's own font 0, BARAM00.EFT from the same set (the face "classic533": a proportional font
-- in a 15 x 16 cell, measured in 12-pixel lines as 5.33's FontImageLib::GetFontMetrics gives them; the classic font,
-- 7.5.2's, without the 5.33 set). Its colours and digits are the original client's palette (interfaces/original/
-- palette.lua; s6-interface-5x-b, round 9, the separation's step 5: 7.x's skin's before): 5.33 uses the same BARAM.PAL
-- indexes and the same 9X11FONT.BIN, byte for byte 7.5.2's. A picture drawn without a palette is BARAM.PAL's, as 5.33
-- blits one its pane names no palette for (the status pane's bars and digits, the clock).
-- Drawing only: nothing here is sent.
-- s6-ui-core (round 85): the XML twin's; the screen, the art's scale, the font and the colours are skin.xml's
-- (core/xml.md).

local H = __tk

local S = setmetatable({}, { __index = require("interfaces.original.palette") })
local D = TK.Xml.Data("skin.xml")
local FONT = D.FONT

-- 5.33's game screen (MainMenuPane::InitializeMainUiGraph 0x00457530: the BackPane is (0, 0)-(640, 480); skin.xml's SCREEN).
S.WIDTH, S.HEIGHT = D.SCREEN.width, D.SCREEN.height

-- s6-interface-5x-b (round 5, the owner's "the character image on the 5x pane might be too large"): the scale 5.x draws
-- the base set's game art at (the figures, the item pictures) in units of its screen. That art is 7.5.2's, drawn twice
-- as large as 5.33's own (Char.dat's bare body, BODY.EPF frame 6: 19 x 27 in 5.33, 36 x 53 in 7.5.2; Misc.dat's
-- ITEM.EPF: 1,798 of 5.33's 2,304 frames exactly half of 7.5.2's, nearly all the rest about half), and 5.33's panes draw
-- its own at 1:1. So 5.x draws 7.5.2's at half, as the world view's 17 live cells of 48 pixels fill the 408-pixel map
-- view (interfaces/screen.lua, Screen.PlaceWorldView): a picture in a pane is the size of the same picture on the map.
S.GAME_ART = D.GAME_ART

-- 5.33's font 0's face, for the texts and the edits (the original-client kit's X.Edit takes it).
S.FACE = FONT.face

--- A font string in 5.33's font 0 and a colour index (S.TEXT by default), its lines 12 pixels apart as 5.33's
--- (GrafPort::DrawTextInRect 0x004381A0 steps a line by the font's 12).
function S.Text(fs, index)
    fs:SetFont(S.FACE, FONT.size, "")
    fs:SetTextColor(S.Colour(index or S.TEXT))
    fs:SetSpacing(FONT.spacing)
    return fs
end

--- A text's width in 5.33's font 0 as 5.33 measures it (GrafPort::GetTextWidth 0x00437E40: its glyphs' advances, a
--- missing glyph counted as '?'), or nil without the packs.
function S.TextWidth(text)
    local ok, w = pcall(function() return H:FaceTextWidth(S.FACE, text or "") end)
    if ok and w and w >= 0 then return w end
    return nil
end

-- More of BARAM.PAL's indexes 5.33's panes use (S.TEXT 0x80 is black, its text colour).
local COLOURS = D.COLOURS
S.WHITE = COLOURS.white -- the chat's background, the status pane's name, the prompt line's background
S.RED, S.BLUE, S.GREEN = COLOURS.red, COLOURS.blue, COLOURS.green

--- Frame n of a 5.33 interface picture (for example "USERSTAT.EPF") in a palette of the same set (BARAM.PAL by
--- default): its key and size, or nil without the 5.33 set.
function S.Image(file, frame, palette)
    local key = "art:533/" .. file:upper() .. "/" .. (frame or 0) .. (palette and ("@" .. palette:upper()) or "")
    local ok, w, h = H:GetArtSize(key)
    if ok then return key, w, h end
end

--- A texture showing frame n of a 5.33 picture with its frame's top left at (x, y) of parent (at its drawn pixels' place:
--- the textures are cropped, TK.Art.Origin); hidden without the picture. Returns the texture, made once when given back as
--- tex.
function S.Picture(parent, tex, file, frame, palette, x, y, layer)
    tex = tex or parent:CreateTexture(nil, layer or "ARTWORK")
    local key, w, h = S.Image(file, frame, palette)
    if not key then
        tex:Hide()
        return tex
    end
    local ox, oy = TK.Art.Origin(key)
    tex:SetTexture(key)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetSize(w, h)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", x + ox, -(y + oy))
    tex:Show()
    return tex
end

--- Windows' MulDiv: a * b / c rounded to the nearest (the status pane's bars).
function S.MulDiv(a, b, c)
    if c == 0 then return -1 end
    return math.floor(a * b / c + 0.5)
end

return S
