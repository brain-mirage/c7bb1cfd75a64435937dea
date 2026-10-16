-- s6-ui-core (build 41): the profile window's picture panel (misc.lua, L.Profile): the player's own picture, with Import
-- and Remove under it. What it does is the shared module's (core/profilepicture.lua, TK.ProfilePicture: the import, the
-- crop window, the picture kept); this file only makes and places its parts. It is the default look's (step 6 of the
-- interface separation, round 46; Modern's before): Modern and 5.x use the default Profile, so they have it; 7.x's
-- Profile is the original's own art, without it. Shown on this client only: nothing here is sent.

local PP = TK.ProfilePicture

local SIDE = 112   -- the panel's width and the picture box's side

--- The panel on parent: the picture's box ("No picture" when there is none), Import and Remove.
return function(parent, W) -- W: the look's skin (misc.lua's, init.lua's Build)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(SIDE, 168)
    p.box = CreateFrame("Frame", nil, p)
    p.box:SetSize(SIDE, SIDE)
    p.box:SetPoint("TOP", p, "TOP", 0, 0)
    p.box:SetBackdrop({ bg = W.innerBg, edge = W.innerEdge, bgFile = W.panelFill })
    p.picture = p.box:CreateTexture(nil, "ARTWORK")
    p.picture:SetPoint("TOPLEFT", p.box, "TOPLEFT", 4, -4)
    p.picture:SetPoint("BOTTOMRIGHT", p.box, "BOTTOMRIGHT", -4, 4)
    p.none = W.Label(p.box, "No picture", 11, W.grey)
    p.none:SetPoint("CENTER", p.box, "CENTER", 0, 0)
    p.import = W.Button(p, "Import...", SIDE, 22, nil, function() PP:ImportForPlayer(function() p:Refresh() end) end)
    p.import:SetPoint("TOP", p.box, "BOTTOM", 0, -6)
    W.Tip(p.import, "A picture from your computer, shown on your screen only.") -- the short text's explanation
    p.remove = W.Button(p, "Remove", SIDE, 22, nil, function()
        PP:Remove()
        p:Refresh()
    end)
    p.remove:SetPoint("TOP", p.import, "BOTTOM", 0, -4)
    function p:Refresh()
        local key = PP:Current()
        self.picture:SetShown(key ~= "")
        self.none:SetShown(key == "")
        if key ~= "" then self.picture:SetTexture(key) end
        if PP:CanImport() then self.import:Enable() else self.import:Disable() end
        if key ~= "" then self.remove:Enable() else self.remove:Disable() end
    end
    p:SetScript("OnShow", function(self) self:Refresh() end)
    p:Refresh()
    return p
end
