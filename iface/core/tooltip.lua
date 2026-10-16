-- GameTooltip: a frame of text lines that sizes itself to its text and sits next to its owner.

local W = TK.UI
local tip = CreateFrame("Frame", "GameTooltip", UIParent)
tip:SetFrameStrata("TOOLTIP")
tip:SetBackdrop({ bg = { 0.03, 0.03, 0.06, 0.92 }, edge = { 0.6, 0.6, 0.65, 1 } })
tip:Hide()
tip.left, tip.right, tip.pics = {}, {}, {}
tip.count = 0

local PAD, GAP = 9, 3

local function line(side, i)
    local t = side == "L" and tip.left or tip.right
    if not t[i] then
        local fs = W.Label(tip, "", i == 1 and 14 or 12, W.white, side == "L" and "LEFT" or "RIGHT")
        t[i] = fs
    end
    return t[i]
end

function tip:SetOwner(owner, anchor)
    self.owner, self.anchor = owner, anchor or "ANCHOR_RIGHT"
    self:ClearLines()
end

function tip:GetOwner() return self.owner end

function tip:ClearLines()
    for _, fs in ipairs(self.left) do fs:Hide() end
    -- s6-spellbook: pairs, as the pictures': a right side is made only for its own line (right = { [2] = ... }), and
    -- ipairs stopped at the first gap, leaving an earlier tooltip's right text on the next one.
    for _, fs in pairs(self.right) do fs:Hide() end
    for _, t in pairs(self.pics) do t:Hide() end
    self.count = 0
end

--- A picture before the last line's text (WoW's AddTexture): a texture key and its size, drawn at most 24 pixels tall.
function tip:AddTexture(key, w, h)
    local i = self.count
    if i == 0 or not key or key == "" then return end
    local t = self.pics[i]
    if not t then
        t = self:CreateTexture(nil, "ARTWORK")
        self.pics[i] = t
    end
    local s = math.min(1, 24 / math.max(1, h or 24))
    t:SetTexture(key)
    t:SetSize((w or 24) * s, (h or 24) * s)
    t:Show()
end

function tip:AddLine(text, r, g, b)
    self.count = self.count + 1
    local fs = line("L", self.count)
    fs:SetText(text)
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    fs:Show()
end

function tip:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
    self:AddLine(left, lr, lg, lb)
    local fs = line("R", self.count)
    fs:SetText(right)
    fs:SetTextColor(rr or 1, rg or 1, rb or 1, 1)
    fs:Show()
end

function tip:SetText(text, r, g, b)
    self:ClearLines()
    self:AddLine(text, r or 1, g or 0.82, b or 0)
end

function tip:Layout()
    local width, y = 0, -PAD
    for i = 1, self.count do
        local l, r, pic = self.left[i], self.right[i], self.pics[i]
        local indent, height = 0, l:GetStringHeight()
        if pic and pic:IsShown() then
            local pw, ph = pic:GetSize()
            indent = pw + 4
            pic:ClearAllPoints()
            pic:SetPoint("TOPLEFT", self, "TOPLEFT", PAD, y)
            height = math.max(height, ph)
        end
        local w = indent + l:GetStringWidth()
        if r and r:IsShown() then w = w + 20 + r:GetStringWidth() end
        width = math.max(width, w)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", self, "TOPLEFT", PAD + indent, y - (height - l:GetStringHeight()) / 2)
        if r and r:IsShown() then
            r:ClearAllPoints()
            r:SetPoint("TOPRIGHT", self, "TOPRIGHT", -PAD, y)
        end
        y = y - height - GAP
    end
    self:SetSize(math.max(80, width + PAD * 2), -y + PAD - GAP)
end

--- Where tooltips go (head note 40; the Tooltips page): "beside" what is hovered (the owner's anchor; the world's
--- objects at the corner, as WoW's), "cursor", or "corner" (the bottom right).
function TK.TooltipAnchor()
    local c = TK.GetComponent("tooltips")
    return c and c:DB().anchor or "beside"
end

function tip:Show()
    self:Layout()
    self:ClearAllPoints()
    local o = self.owner
    local a = self.anchor
    local where = TK.TooltipAnchor()
    if where == "cursor" then a = "ANCHOR_CURSOR" elseif where == "corner" then a = "ANCHOR_CORNER" end
    if a == "ANCHOR_CORNER" then
        self:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -18, 110)
    elseif a == "ANCHOR_CURSOR" or not o then
        local x, y = TK.Util.CursorRoot()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x + 16, y + 8)
    elseif a == "ANCHOR_LEFT" then
        self:SetPoint("BOTTOMRIGHT", o, "TOPLEFT", 0, 4)
    elseif a == "ANCHOR_TOP" then
        self:SetPoint("BOTTOM", o, "TOP", 0, 4)
    elseif a == "ANCHOR_BOTTOM" then
        self:SetPoint("TOP", o, "BOTTOM", 0, -4)
    else
        self:SetPoint("BOTTOMLEFT", o, "TOPRIGHT", 0, 4)
    end
    TK.FrameClasses.Frame.Show(self)
    -- Keep it on the screen.
    local l, b, w, h = TK.Util.RootRect(self)
    if l then
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        local dx = (l + w > sw) and (sw - (l + w) - 4) or (l < 0 and -l + 4 or 0)
        local dy = (b + h > sh) and (sh - (b + h) - 4) or (b < 0 and -b + 4 or 0)
        if dx ~= 0 or dy ~= 0 then
            self:ClearAllPoints()
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l + dx, b + dy)
        end
    end
end

function tip:Hide()
    self.owner = nil
    TK.FrameClasses.Frame.Hide(self)
end

-- ----- spells: the learned mana cost (plan 5.11; the session's snapshot.Learned) -----

--- A spell's mana cost as learned from the player's own casts on this server, or nil (never cast yet).
function TK.SpellCost(name)
    local known, mana = __tk:GetSpellCost(name or "")
    if known then return mana end
end

--- Adds the spell's learned cost to the tooltip being built, when there is one.
function TK.AddSpellCostLine(name)
    local cost = TK.SpellCost(name)
    if cost then GameTooltip:AddLine("Costs " .. TK.Util.FormatNumber(cost) .. " mana", 0.55, 0.7, 1) end
end

--- The mana-cost preview while a spell is hovered (hotbar, spell book, action wheel); nothing for a spell whose cost is
--- not learned. Hide on leaving. s6-input (round 49, separation step 4b; W7): an interface's frame draws it (Modern's
--- player frame), so this fires TK_MANA_PREVIEW with the cost (nil: none) instead of drawing on that frame. s6-ui-core
--- (round 82): and the spell's name, so a frame can preview what else the Library learned of it (its health cost, its
--- healing or damage on the target: TK.SpellInfo); nil on leaving.
TK.ManaPreview = {}

function TK.ManaPreview.Show(name) TK.FireEvent("TK_MANA_PREVIEW", TK.SpellCost(name), name) end

function TK.ManaPreview.Hide() TK.FireEvent("TK_MANA_PREVIEW", nil) end

-- ----- the world's tooltip (s6-input round 49, separation step 4b; interface-separation.md 5.12) -----

local worldTipOwner

--- A frame drawn over the world that shows its own tooltip there (Modern's effect icons) claims the world's tooltip while
--- it shows it; nil gives it back. The world-object tooltip (components/tooltips) yields while it is claimed. Drawing only.
function TK.ClaimWorldTip(frame) worldTipOwner = frame end

--- Whether a frame over the world has the world's tooltip now (its claim, while that frame is visible).
function TK.WorldTipClaimed() return worldTipOwner ~= nil and worldTipOwner:IsVisible() end
