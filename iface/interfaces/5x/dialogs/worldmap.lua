-- 5.33's FIELD pictures: WorldMapPane constructor 0x004E4B80 and paint 0x004E51A0.
-- FIELD1/10..18 are 640x480. Only their drawing changes: the shared renderer keeps 4a's view, hover,
-- hit tests and travel rules (0x005C40C0/0x005C3E50); changing those changes what the server sees.
local S = require("interfaces.5x.skin")
return function(L)
    local art = { width = 640, height = 480, image = S.Image, figureScale = S.GAME_ART }
    -- 5.33 offsets each frame's rectangle by (-20,-34). Exported textures are cropped:
    -- retain that frame's origin and size when the hover selects the other WMICON frame.
    function art.symbol(b, frame)
        local key, w, h = S.Image("WMICON.EPF", frame, "BARAM.PAL")
        if key then
            local ox, oy = TK.Art.Origin(key) -- mask crop within this frame
            -- WMICON frame rectangles start at (7,6)/(4,3) in the native EPF canvas.
            local left, top = frame == 0 and 7 or 4, frame == 0 and 6 or 3
            b.symbol:ClearAllPoints()
            b.symbol:SetPoint("TOPLEFT", b, "CENTER", -20 + left + ox, 34 - top - oy)
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
