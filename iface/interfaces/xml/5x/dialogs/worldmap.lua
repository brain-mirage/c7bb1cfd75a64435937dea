-- 5.33's FIELD pictures: WorldMapPane constructor 0x004E4B80 and paint 0x004E51A0.
-- FIELD1/10..18 are 640x480. Only their drawing changes: the shared renderer keeps 4a's view, hover,
-- hit tests and travel rules (0x005C40C0/0x005C3E50); changing those changes what the server sees.
--
-- s6-ui-core (round 85): the XML twin's; the pictures' size and the symbol's file and offsets are worldmap.xml's
-- (core/xml.md).
local S = require("interfaces.5x.skin")
local D = TK.Xml.Data("worldmap.xml")
return function(L)
    local art = { width = D.ART.width, height = D.ART.height, image = S.Image, figureScale = S.GAME_ART }
    local SYMBOL = D.SYMBOL
    -- 5.33 offsets each frame's rectangle (worldmap.xml's SYMBOL). Exported textures are cropped:
    -- retain that frame's origin and size when the hover selects the other WMICON frame.
    function art.symbol(b, frame)
        local key, w, h = S.Image(SYMBOL.file, frame, SYMBOL.palette)
        if key then
            local ox, oy = TK.Art.Origin(key) -- mask crop within this frame
            -- WMICON frame rectangles start at SYMBOL's first (frame 0) or other in the native EPF canvas.
            local at = frame == 0 and SYMBOL.first or SYMBOL.other
            b.symbol:ClearAllPoints()
            b.symbol:SetPoint("TOPLEFT", b, "CENTER", SYMBOL.x + at[1] + ox, -SYMBOL.y - at[2] - oy)
            b.symbol:SetSize(w, h)
        end
        return key
    end
    function art.node(b) S.Text(b.label, S.WHITE) end
    L.WorldMap = {
        select = function(name)
            if name:match("^FIELD%d+$") and S.Image(name .. ".EPF", 0, name .. ".PAL") then return art end
        end,
    }
end
