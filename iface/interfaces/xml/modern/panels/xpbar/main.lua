-- The XP bar, as Bartender's: a long experience bar, with its numbers shown never, on mouse-over or always.
-- s6-ui-core (round 85): the XML twin's scripts; the bar, its edge, ticks and text are main.xml's (core/xml.md).

local C = TK.GetComponent("xpbar")
local H = __tk
local U = TK.Util
local E = require("interfaces.modern.elements")

-- the scripts main.xml names
local scripts = {}

function scripts.Enter(f) f.hover = true; C:Update() end

function scripts.Leave(f) f.hover = false; C:Update() end

function scripts.Changed() C:Update() end

function C:OnEnable()
    local f = TK.Xml.Load("main.xml", { scripts = scripts, elements = E }).frame
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
