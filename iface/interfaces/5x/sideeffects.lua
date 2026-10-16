-- 5.33's InterfaceEfxMgr (0x0044F9C0/0x0044FCE0): independent character, item and
-- magic animations at the side panel's origin, gated at start by Shadow & Lighting.
-- The shared side-panel event owns activation; this file owns only native art/layout.
local S = require("interfaces.5x.skin")
local Animation = require("interfaces.original.spriteanimation")
local NATIVE = { char = "CHREFX.EPF", item = "ITEMEFX.EPF", magic = "MAGEFX.EPF" }
local TAB = { [0] = "char", [1] = "char", [2] = "item", [3] = "magic" }

return function(parent)
    local mgr = { effects = {}, stack = {} }
    for id, file in pairs(NATIVE) do
        local art = { count = 12, delay = 0.040 }
        function art.available() return S.Image(file, 0, "INTEFX.PAL") ~= nil end
        function art.draw(f, index)
            local key, w, h = S.Image(file, index, "INTEFX.PAL")
            if not key then f.image:Hide() return end
            local left, top = TK.Art.FrameRect(key)
            if left == nil then f.image:Hide() return end
            -- OnTimer 0x0044F770 moves by the canvas origin, separate from the mask crop.
            -- Pane(1)'s compositor (0x00437830) color-keys the paint's zero clear: only
            -- the masked sprite is visible, never an opaque background over the page.
            local ox, oy = TK.Art.Origin(key)
            f.image:ClearAllPoints()
            f.image:SetPoint("TOPLEFT", f, "TOPLEFT", left + ox, -top - oy)
            f.image:SetSize(w, h)
            f.image:SetTexture(key)
            f.image:Show()
        end
        local f = Animation(parent, art)
        f.image = f:CreateTexture(nil, "ARTWORK")
        mgr.effects[id] = f
    end

    function mgr:Trigger(tab)
        local effect = self.effects[TAB[tab]]
        if not effect or not parent:IsShown() or not TK.Game.Options.Shadows() then return false end
        -- Start re-adds just this effect in front; keep the other instances' relative order.
        -- Renumber the three decorations so UIFrame's level clamp never flattens their order.
        for i, f in ipairs(self.stack) do
            if f == effect then table.remove(self.stack, i) break end
        end
        table.insert(self.stack, effect)
        for i, f in ipairs(self.stack) do f:SetFrameLevel(parent:GetFrameLevel() + 100 + i) end
        return effect:Start()
    end
    return mgr
end
