-- s6-ui-core (round 82; the owner's request of 2026-10-09, docs/user-related/requests/2026-10-09-health-mana-bars-and-
-- target-info.md): Modern's health and mana bars (the player and party frames, and the bars over others the nameplates
-- draw) and what they show besides their fill:
--   the numbers in the form chosen, on one line, or as two rows over the bar when one line is wider than it (health and
--   mana reach the millions);
--   the damage taken: the part just lost turns red, waits a moment and shrinks away (a switch on each bar's page);
--   a hovered spell's cost: a small red triangle under the bar, its tip at the cost's place counted from the left;
--   a spell's healing or damage previewed on a bar whose value is known in points.
-- Drawing only: nothing here is sent or asked of the server.

local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin
local U = TK.Util

local V = {}

--- The number forms, in the settings' order (each bar page's Number Format).
V.FORMATS = {
    { value = "current", text = "4,100" },
    { value = "value", text = "4,100 / 5,200" },
    { value = "percent", text = "79%" },
    { value = "currentpercent", text = "4,100 (79%)" },
    { value = "both", text = "4,100 / 5,200 (79%)" },
}

V.HOLD, V.SHRINK = 0.3, 0.6 -- the damage taken: seconds it stays, then seconds it takes to shrink away
local LOSS = { 0.9, 0.12, 0.1, 0.9 }
--- The damage taken on a bar whose own fill is red (the NPCs' bars over heads; a bar's lossColour): light, so it shows.
V.LOSS_ON_RED = { 1, 0.82, 0.5, 0.95 }
local MARK = { 0.95, 0.15, 0.1, 1 }
local HEAL, HIT = { 0.55, 1, 0.55, 0.55 }, { 0.15, 0, 0, 0.6 }

--- A vital bar (W.VitalBar) that keeps its text size, for the second row.
function V.Bar(parent, height, r, g, b, textSize, name)
    local bar = W.VitalBar(parent, height, r, g, b, textSize, name)
    bar.textSize = textSize
    return bar
end

--- The numbers as one line, and as two rows (the second nil when the form has one part); for Both also a narrower pair
--- of rows, for a bar too narrow for the values on one row. A value known only as a percentage (max nil) shows the
--- percentage, whatever the form.
function V.Parts(cur, max, form)
    if not max then return cur .. "%" end
    local c, m = U.FormatNumber(cur), U.FormatNumber(max)
    local p = (max > 0 and math.floor(cur / max * 100 + 0.5) or 0) .. "%"
    if form == "current" then return c end
    if form == "percent" then return p end
    if form == "value" then return c .. " / " .. m, c, "/ " .. m end
    if form == "currentpercent" then return c .. " (" .. p .. ")", c, p end
    return c .. " / " .. m .. " (" .. p .. ")", c .. " / " .. m, p, c .. " (" .. p .. ")", "/ " .. m
end

--- Writes the numbers on a bar (form nil: none). One line while it fits the bar, else two rows over it, centred on it as
--- one block. Returns the rows shown (0, 1 or 2): a frame gives a bar of two rows the height for them (V.Height).
function V.Numbers(bar, cur, max, form)
    local text = bar.text
    local line, top, bottom, narrowTop, narrowBottom
    if form then line, top, bottom, narrowTop, narrowBottom = V.Parts(cur, max, form) end
    text:SetText(line or "")
    local w = bar:GetWidth()
    local rows = not line and 0 or (bottom and w > 0 and text:GetStringWidth() > w - 4) and 2 or 1
    if rows == 2 then
        if not bar.text2 then
            bar.text2 = W.Label(bar, "", bar.textSize, W.white)
            bar.text2:SetFont(bar.textSize, "OUTLINE")
        end
        text:SetText(top)
        if narrowTop and text:GetStringWidth() > w - 4 then -- Both's values too wide for one row: the narrower pair
            top, bottom = narrowTop, narrowBottom
            text:SetText(top)
        end
        bar.text2:SetText(bottom)
    end
    if bar.rows ~= rows then
        local h = (bar.textSize or 11) / 2 + 1
        text:ClearAllPoints()
        text:SetPoint("CENTER", bar, "CENTER", 0, rows == 2 and h or 0)
        if bar.text2 then
            bar.text2:ClearAllPoints()
            bar.text2:SetPoint("CENTER", bar, "CENTER", 0, -h)
            bar.text2:SetShown(rows == 2)
        end
        bar.rows = rows
    end
    return rows
end

--- A bar's height: its own, or room for two rows of its text when the numbers take two.
function V.Height(bar, height)
    if bar.rows == 2 then return math.max(height, 2 * (bar.textSize or 11) + 4) end
    return height
end

--- A part of the bar, from and to in its values (cut to 0..max), drawn by tex; hidden when empty.
function V.Span(tex, bar, from, to, max)
    local w = bar:GetWidth()
    from, to = math.max(0, math.min(from, max)), math.max(0, math.min(to, max))
    if max <= 0 or w <= 0 or to <= from then return tex:Hide() end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", bar, "TOPLEFT", w * from / max, 0)
    tex:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", w * from / max, 0)
    tex:SetWidth(w * (to - from) / max)
    tex:Show()
end

local function texture(bar, layer, c)
    local t = bar:CreateTexture(nil, layer)
    t:SetColorTexture(c[1], c[2], c[3], c[4])
    t:Hide()
    return t
end

--- The damage taken's red part this moment: its top while it waits, then shrinking to the value; nil once gone.
local function lossTop(bar)
    if not bar.lossTop then return nil end
    local k = (GetTime() - bar.lossAt - V.HOLD) / V.SHRINK
    if k >= 1 then return nil end
    return bar.lossTop - (bar.lossTop - bar.value) * math.max(0, k)
end

local function drawLoss(bar)
    local top = lossTop(bar)
    if not top then
        bar.lossTop = nil
        bar.loss:Hide()
        bar:SetScript("OnUpdate", nil)
        return
    end
    V.Span(bar.loss, bar, bar.value, top, bar.max)
end

--- Sets a bar's value of max. loss: the damage taken is shown (its page's switch): a fall turns the part lost red, which
--- waits V.HOLD seconds and shrinks away in V.SHRINK; a fall during that adds to it, a rise to its top or a new maximum
--- ends it.
function V.Set(bar, value, max, loss)
    local old, oldMax = bar.value, bar.max
    local shown = loss and lossTop(bar)
    bar.value, bar.max = value, max
    bar:SetMinMaxValues(0, max)
    bar:SetValue(value)
    if loss and old and oldMax == max and value < old then
        bar.lossTop = math.max(shown or old, old)
        bar.lossAt = GetTime()
        bar.loss = bar.loss or texture(bar, "BORDER", LOSS)
        local c = bar.lossColour or LOSS
        if bar.lossDrawn ~= c then
            bar.loss:SetColorTexture(c[1], c[2], c[3], c[4])
            bar.lossDrawn = c
        end
        bar:SetScript("OnUpdate", drawLoss)
    elseif not shown or oldMax ~= max or value >= shown then
        bar.lossTop = nil
    end
    if bar.loss then drawLoss(bar) end
end

--- Forgets what a bar showed (a bar given to another unit): its value, the damage taken and the preview.
function V.Reset(bar)
    bar.value, bar.max, bar.lossTop = nil, nil, nil
    if bar.loss then bar.loss:Hide() end
    bar:SetScript("OnUpdate", nil)
    if bar.preview then bar.preview:Hide() end
end

--- A small red triangle under the bar, its tip at value's place from the bar's left (the owner: mana 1000, a spell of
--- 750: the mark at 750); nil or 0 hides it. Rows of 1, 3, 5 and 7 pixels, the tip against the bar's bottom, drawn over
--- what is below the bar.
function V.Mark(bar, value, max)
    local m = bar.mark
    if not (value and value > 0 and max and max > 0) then
        if m then m:Hide() end
        return
    end
    if not m then
        m = CreateFrame("Frame", nil, bar)
        m:SetSize(7, 4)
        m:SetFrameLevel(bar:GetFrameLevel() + 3)
        for k = 1, 4 do
            local row = m:CreateTexture(nil, "OVERLAY")
            row:SetColorTexture(MARK[1], MARK[2], MARK[3], MARK[4])
            row:SetSize(2 * k - 1, 1)
            row:SetPoint("TOP", m, "TOP", 0, 1 - k)
        end
        bar.mark = m
    end
    m:ClearAllPoints()
    m:SetPoint("TOP", bar, "BOTTOMLEFT", bar:GetWidth() * math.min(value, max) / max, 0)
    m:Show()
end

--- A spell's effect previewed on the bar (amount nil hides it): healing ("heal") as a light part from the value up,
--- damage as a dark part down from the value. Only on a bar whose value is in points (V.Set's).
function V.Preview(bar, amount, kind)
    local t = bar.preview
    if not (amount and amount > 0 and bar.max and bar.max > 0) then
        if t then t:Hide() end
        return
    end
    if not t then
        t = texture(bar, "OVERLAY", HEAL)
        bar.preview = t
    end
    local c = kind == "heal" and HEAL or HIT
    t:SetColorTexture(c[1], c[2], c[3], c[4])
    if kind == "heal" then
        V.Span(t, bar, bar.value, bar.value + amount, bar.max)
    else
        V.Span(t, bar, bar.value - amount, bar.value, bar.max)
    end
end

--- What a hovered spell would heal or take, as the Library learned it from the player's own casts (TK.SpellInfo):
--- amount and "heal" or "damage"; nil when neither is known.
function V.SpellEffect(name)
    if not name then return nil end
    local info = TK.SpellInfo:Get(name)
    if info.healing and info.healing > 0 then return info.healing, "heal" end
    if info.damage and info.damage > 0 then return info.damage, "damage" end
end

return V
