-- The XP bar, as Bartender's: a long experience bar, with its numbers shown never, on mouse-over or always.

local C = TK.GetComponent("xpbar")
local H = __tk
local U = TK.Util
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin

function C:OnEnable()
    local f = CreateFrame("StatusBar", "TKXPBar", UIParent)
    f:SetStatusBarTexture("tk:bar")
    f:SetStatusBarColor(0.58, 0.25, 0.85, 1)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0.08, 0.04, 0.12, 0.85)
    local edge = f:CreateTexture(nil, "OVERLAY")
    edge:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    edge:SetTexture("tk:edge")
    edge:SetVertexColor(0.1, 0.1, 0.1, 1)
    -- Tick marks every tenth, as in WoW.
    f.ticks = {}
    for i = 1, 9 do
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetWidth(1)
        t:SetColorTexture(0, 0, 0, 0.5)
        f.ticks[i] = t
    end
    f.text = W.Label(f, "", 10, W.white)
    f.text:SetFont(10, "OUTLINE")
    f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function() f.hover = true; self:Update() end)
    f:SetScript("OnLeave", function() f.hover = false; self:Update() end)
    f:RegisterEvent("PLAYER_XP_UPDATE")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function() self:Update() end)
    self.frame = f
    TK.Visibility:Attach(f, function() return self:DB() end)
    TK.EditMode:Register(f, "xpbar", "XP Bar", C.defaultPosition, "xpbar")
end

function C:Update()
    local db, f = self:DB(), self.frame
    local _, xp, xpMax = H:GetPlayerXP()
    f:SetMinMaxValues(0, xpMax)
    f:SetValue(xp)
    local show = db.showText == "always" or (db.showText == "hover" and f.hover)
    if show then
        local pct = xpMax > 0 and xp / xpMax * 100 or 0
        if H:IsOnline() then
            -- The server sends the bar's percent (0x08) and the experience itself, not what the level needs.
            f.text:SetText(string.format("XP %s (%d%%)", U.FormatNumber(H:GetExperience()), math.floor(pct + 0.5)))
        else
            f.text:SetText(string.format("XP %s / %s (%.1f%%)", U.FormatNumber(xp), U.FormatNumber(xpMax), pct))
        end
    else
        f.text:SetText("")
    end
end

function C:ApplySettings()
    local db, f = self:DB(), self.frame
    f:SetSize(db.width, db.height)
    for i, t in ipairs(f.ticks) do
        t:ClearAllPoints()
        t:SetPoint("TOP", f, "TOPLEFT", db.width * i / 10, 0)
        t:SetPoint("BOTTOM", f, "BOTTOMLEFT", db.width * i / 10, 0)
    end
    self:Update()
    TK.Visibility:Apply(f)
end
