-- Shared original-interface animation clock. The caller owns the art, rectangles and delay;
-- this decoration never registers input, sends packets or draws from the game's random stream.
-- InterfaceEfx::Start/OnTimer (4a 0x004E9950/0x004E9B20): first frame on the next update,
-- one frame per due callback, then a fresh delay. A late callback does not skip frames.
return function(parent, art)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:EnableMouse(false)
    f:Hide()
    f.index, f.playing = -1, false

    function f:Stop()
        self.playing = false
        self:Hide()
    end

    function f:Start()
        if not art.available() then return false end
        self.index, self.wait, self.playing = -1, 0, true
        self:Show()
        return true
    end

    -- Empty images are animation steps too: only reaching count ends the effect.
    function f:Advance(elapsed)
        if not self.playing then return end
        self.wait = self.wait - elapsed
        if self.wait > 0 then return end
        self.index = self.index + 1
        if self.index == art.count then return self:Stop() end
        art.draw(self, self.index)
        self.wait = art.delay
    end

    f:SetScript("OnUpdate", function(_, elapsed) f:Advance(elapsed) end)
    f:SetScript("OnHide", function() f.playing = false end)
    return f
end
