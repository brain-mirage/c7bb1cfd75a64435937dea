-- A native item's frame centred on a point, including the packed mask crop.
-- Rows and passive drag labels draw the whole frame; 7.x inventory cells cut the source.
-- This changes drawing only, not the item's input, drag or packet path.
local H = __tk

return function(tex, parent, iconId, cx, cy, scale, clipSize, colour, still)
    scale = scale or 1
    local key, w, h
    if still and colour and colour ~= 0 then
        -- A held label lives on the dialog layer, outside the active panel's palette
        -- repaint. Its pointer movement asks for the new phase (4a HelpPane 0x004C7F00).
        key, w, h = TK.Art.Item((iconId + 0xC000) % 0x10000, colour)
    else key, w, h = TK.Art.Icon(iconId, colour) end
    if not key then tex:Hide() return 0, 0 end
    local ok, fw, fh = H:GetArtFrameSize(key)
    if not ok then fw, fh = w, h end
    local ox, oy = TK.Art.Origin(key)
    local dw, dh = w, h
    if clipSize then
        -- 4a ItemObjImageLib::DrawItemImageIn43x43Slot (0x004DEFC0) cuts the source
        -- from its top left before centring it. Keep its natural size, not a shrink
        -- of the whole item. The packed mask's origin remains relative to that frame.
        fw, fh = math.min(fw, clipSize), math.min(fh, clipSize)
        dw, dh = math.min(w, math.max(0, fw - ox)), math.min(h, math.max(0, fh - oy))
    end
    if dw == 0 or dh == 0 then tex:Hide() return 0, 0 end
    local sw, sh = math.floor(fw * scale), math.floor(fh * scale)
    tex:SetTexture(key)
    -- Reset the source rectangle too when a texture is reused by a whole-frame row.
    tex:SetTexCoord(0, dw / w, 0, dh / h)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:SetSize(math.max(1, math.floor(dw * scale)), math.max(1, math.floor(dh * scale)))
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", cx - math.floor(sw / 2) + math.floor(ox * scale),
        -(cy - math.floor(sh / 2) + math.floor(oy * scale)))
    tex:Show()
    return sw, sh
end
