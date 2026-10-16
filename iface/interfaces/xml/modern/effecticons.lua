-- Modern's effect icons (s6-modular-g round 16, separation step 7; docs/development/interface-separation.md 4.1 and 4.2):
-- the icon group the icons on units (panels/enemyicons) and the target frame's row (panels/targetframe) share, with
-- the effects' pictures (data/effects.lua beside this file), moved unchanged from core/effecticons.lua (s6-ui-core
-- round 43), whose logic stays every interface's (TK.EffectIcons: the names and kinds, the player's two name lists,
-- the filters, the peers' words, the times as text).
--
-- Each effect is a very small icon: its name's picture, else a small square in its kind's colour with the name's first
-- letter ("?" when unknown); optionally its time as tiny text under it. The tooltip gives the name or "???", where it
-- comes from, and the time ("4:47 left", "about 30-60 s left", "0-20 s left, possibly over", "time unknown"). The look is
-- the style table below. Display only: nothing here is sent.
-- s6-ui-core (round 85): the XML twin's; the style, the icon and the group are effecticons.xml's (core/xml.md).

local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local U = TK.Util
local E = TK.EffectIcons
local art = require("interfaces.modern.data.effects")

local G = {}

-- the scripts effecticons.xml names
local scripts = {}

local ui = TK.Xml.Load("effecticons.xml", { scripts = scripts, elements = require("interfaces.modern.elements") })

G.style = ui.style

--- A column's width: the icon's, or a time's under it when times are shown (wider than a very small icon).
function G.ColumnWidth(size, timeText)
    return timeText and math.max(size, G.style.timeWidth) or size
end

--- An effect's icon key by the name the server gave it (Modern's buffs and debuffs, panels/auras), the unknown one's
--- when Modern's data names none (it was TK.EffectIcons.Classify's second result).
function G.Icon(name)
    return "emoji:" .. (art.icons[name] or art.unknownIcon)
end

--- The picture for it (an emoji key), when Modern's data has one for its name or first candidate (" (Caster)" left
--- out, TK.EffectIcons.Base); else nil.
function G.Picture(b)
    local icon = art.icons[E.Base(b.name ~= "" and b.name or E.Candidates(b)[1])]
    return icon and ("emoji:" .. icon) or nil
end

--- The tooltip for one effect, beside its icon.
function G.ShowTooltip(owner, b)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    local kind = E.Kind(b)
    local e = G.style.edge[kind]
    GameTooltip:AddLine(E.Label(b), 1, 1, 1)
    GameTooltip:AddLine((kind == "unknown" and "Unknown kind" or (kind == "buff" and "Buff" or "Debuff")) .. ", " .. E.Source(b),
        e[1], e[2], e[3])
    GameTooltip:AddLine(E.LongTime(b), 0.85, 0.85, 0.85)
    if (b.effect or 0) > 0 then GameTooltip:AddLine("Effect #" .. b.effect .. " (for the name lists)", 0.6, 0.6, 0.6) end
    if owner.listMenu then GameTooltip:AddLine("Right-click: put it on a list", 0.5, 0.8, 1) end -- round 44
    GameTooltip:Show()
end

--- Round 44 (the owner: names put on the lists from the icons): an icon's menu, at the pointer: Add to Buffs, Add to
--- Debuffs, Take Off the Lists, for its name, each of its candidates, or its graphic's number (E.Entries). Local only.
function G.ListMenu(b)
    local entries = E.Entries(b)
    local items = { { text = E.Label(b), title = true } }
    if #entries == 0 then
        items[#items + 1] = { text = "Nothing to list yet: no name or number", disabled = true }
    else
        local all = { buff = true, debuff = true }
        local any = false
        for _, entry in ipairs(entries) do
            local on = E.ListOf(entry)
            if on ~= "buff" then all.buff = false end
            if on ~= "debuff" then all.debuff = false end
            any = any or on ~= nil
        end
        local function put(kind)
            for _, entry in ipairs(entries) do E.MoveToList(entry, kind) end
            E.ListsChanged()
        end
        items[#items + 1] = { text = "Add to Buffs", disabled = all.buff, onClick = function() put("buff") end }
        items[#items + 1] = { text = "Add to Debuffs", disabled = all.debuff, onClick = function() put("debuff") end }
        if any then
            items[#items + 1] = { text = "Take Off the Lists", onClick = function()
                for _, entry in ipairs(entries) do E.RemoveFromLists(entry) end
                E.ListsChanged()
            end }
        end
    end
    W.OpenMenu(items)
end

--- Round 44: whether a group's icons open the list menu on a right-click. Icons that take no mouse (over the world) then
--- claim the right button only (Frame:SetClaimButtons): the hover, the map cursor and the left button stay the map's.
function G.SetListMenu(g, on)
    g.listMenu = on and true or false
    for _, f in ipairs(g.icons) do
        f.listMenu = g.listMenu
        if not g.mouse then
            if g.listMenu then f:SetClaimButtons("RightButton") else f:SetClaimButtons() end
        end
    end
end

-- Round 44: a right-click puts the effect's name on a list (G.ListMenu), where the group allows it (G.SetListMenu).
function scripts.ListMenu(self, button)
    if button == "RightButton" and self.listMenu and self.row then G.ListMenu(self.row) end
end

local function icon(g, i)
    local f = g.icons[i]
    if f then return f end
    f = ui:New("Icon", g, g.name .. "Icon" .. i)
    if g.mouse then
        f:EnableMouse(true)
        f:SetScript("OnEnter", function(self) if self.row then G.ShowTooltip(self, self.row) end end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    f.listMenu = g.listMenu
    if g.listMenu and not g.mouse then f:SetClaimButtons("RightButton") end
    g.icons[i] = f
    return f
end

--- Round 44: a group about to be hidden lets go of the tooltip one of its icons shows.
function G.Release(g)
    for _, f in ipairs(g.icons) do
        if GameTooltip:GetOwner() == f then GameTooltip:Hide() end
    end
end

--- A group of icons on a parent. mouse: the icons take the mouse for their tooltip (the target frame's); without it the
--- owner shows the tooltip itself (G.IconAt), so the icons over the world never take a click meant for a figure.
function G.NewGroup(parent, name, mouse)
    local g = ui:New("Group", parent, name)
    g.name, g.icons, g.mouse = name, {}, mouse
    return g
end

--- Shows the arranged rows (E.Arrange) as icons: opts.size, opts.perRow, opts.max ("+n" past it) and opts.timeText;
--- round 44: opts.ownSize, the size of our own casts' effects (row.own), larger as WoW draws the player's own auras (the
--- report's section 5.2). The group takes the rows' size; its owner anchors it. Returns how many icons show.
function G.Show(g, list, opts)
    local size, perRow, max = opts.size or 12, math.max(1, opts.perRow or 6), math.max(1, opts.max or 12)
    local gap = G.style.gap
    local text = opts.timeText
    local n = math.min(#list, max)
    local own = opts.ownSize or size
    local largest = size
    for i = 1, n do
        if list[i].row.own then largest = math.max(largest, own) end
    end
    local colW = G.ColumnWidth(largest, text)
    local rowH = largest + gap + (text and 9 or 0)
    for i = 1, n do
        local item = list[i]
        local f = icon(g, i)
        local b, kind = item.row, item.kind
        local s = b.own and own or size
        local fontSize = math.max(7, math.floor(s * 0.6))
        f.row = b
        f:SetSize(s, s)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", g, "TOPLEFT", ((i - 1) % perRow) * (colW + gap) + math.floor((colW - s) / 2),
            -math.floor((i - 1) / perRow) * rowH - (largest - s))
        local fill, edge = G.style.fill[kind], G.style.edge[kind]
        f.fill:SetColorTexture(fill[1], fill[2], fill[3], fill[4])
        for k = 1, 4 do
            f.edge[k]:SetColorTexture(edge[1], edge[2], edge[3], edge[4])
            if k <= 2 then f.edge[k]:SetHeight(1) else f.edge[k]:SetWidth(1) end
        end
        local picture = G.Picture(b)
        f.picture:SetShown(picture ~= nil)
        if picture then f.picture:SetTexture(picture) end
        local label = E.Label(b)
        f.letter:SetText(picture and "" or (label == "???" and "?" or label:sub(1, 1):upper()))
        f.letter:SetFont(fontSize, "OUTLINE")
        local t = text and E.ShortTime(b) or nil
        f.time:SetText(t or "")
        f.time:SetShown(t ~= nil)
        f:SetAlpha(b.estimate and not b.exact and G.style.estimateAlpha or 1)
        f:Show()
        -- Round 44 (Astra P2): an icon's tooltip follows its row as it is replaced (its time counts down, and a new
        -- target's effect in that place is shown, not the last one's).
        if GameTooltip:IsShown() and GameTooltip:GetOwner() == f then G.ShowTooltip(f, b) end
    end
    for i = n + 1, #g.icons do
        g.icons[i].row = nil
        g.icons[i]:Hide()
        if GameTooltip:GetOwner() == g.icons[i] then GameTooltip:Hide() end
    end
    local cols = math.min(math.max(n, 1), perRow)
    local rows = math.max(1, math.ceil(n / perRow))
    g.more:SetShown(#list > n)
    if #list > n then
        g.more:SetText("+" .. (#list - n))
        g.more:ClearAllPoints()
        g.more:SetPoint("LEFT", g, "TOPLEFT", cols * (colW + gap), -(rows - 1) * rowH - largest / 2)
    end
    g:SetSize(cols * (colW + gap) - gap + (#list > n and 18 or 0), rows * rowH - gap)
    return n
end

--- The shown icon of a group under a point of the UI's root (U.CursorRoot()), or nil.
function G.IconAt(g, x, y)
    if not g:IsVisible() then return nil end
    for _, f in ipairs(g.icons) do
        if f.row and f:IsShown() then
            local l, b, w, h = U.RootRect(f)
            if l and x >= l and x <= l + w and y >= b and y <= b + h then return f end
        end
    end
    return nil
end

return G
