-- The original item sheet's reusable painter: inventory and worn record metadata, durability, owner and protection.
-- Each original interface supplies its font/palette and placement kit. The game layer owns the singleton, ten-second
-- lifetime and input rules (core/game/itemhelp.lua; WIRE: 4a ItemHelpPane constructor/handlers 0x004C82D0/0x004CCC40).
local H = __tk
return function(ctx)
    local S = ctx.skin
    local Help = ctx.help

    local B = {}

    -- The one box shown (4a keeps one: Singleton<ItemHelpPane>).
    local box

    --- C's integer division (toward zero), as 4a's centring divides.
    local function div(a, b) local q = a / b return q >= 0 and math.floor(q) or math.ceil(q) end

    --- _wtol: leading spaces, a sign and digits; 0 for none.
    local function wtol(s)
        local sign, digits = (s or ""):match("^%s*([+-]?)(%d+)")
        if not digits then return 0 end
        return (sign == "-" and -1 or 1) * math.floor(tonumber(digits))
    end

    local function width(text) return S.TextWidth(text) or 0 end

    --- The lines GrafPort::DrawTextInRect breaks text into at max pixels, as ItemHelpPane::CountTextLines counts them:
    --- as many characters as fit (CountCharsFittingWidth: their advances' sum at most max), a space that ends a line skipped.
    local function wrap(text, max)
        local chars = {}
        for _, c in utf8.codes(text or "") do chars[#chars + 1] = utf8.char(c) end
        local lines, at = {}, 1
        while at <= #chars do
            local n = 0
            while at + n <= #chars and width(table.concat(chars, "", at, at + n)) <= max do n = n + 1 end
            n = math.max(1, n) -- a character wider than the line: one a line (4a's loop would not end)
            lines[#lines + 1] = table.concat(chars, "", at, at + n - 1)
            at = at + n
            if chars[at] == " " then at = at + 1 end
        end
        return lines
    end

    --- A price with thousands commas, as PopulateItemData writes it (a comma after every third digit from the right, the
    --- last one dropped).
    local function commas(s)
        local out, n = {}, #s
        if n == 0 then return "" end
        for c = 1, n do
            out[#out + 1] = s:sub(c, c)
            if (n - c) % 3 == 0 then out[#out + 1] = "," end
        end
        out[#out] = nil
        return table.concat(out)
    end

    -- The property table's labels (PopulateItemData's), and the bonus rows in the order OnPaint draws them
    local LABELS = { [2] = "Durability ", [18] = "Damage S ", [19] = "       L ", [3] = "Armor    ", [4] = "Hit    ",
                     [5] = "Damage ", [6] = "Vitality increase ", [7] = "Mana increase     ", [8] = "Might increase    ",
                     [10] = "Will increase     ", [9] = "Grace increase    ", [11] = "Wisdom increase   ", [12] = "Con    ",
                     [16] = "Regen  ", [17] = "Protection " }
    local BONUS = { 3, 4, 5, 6, 7, 8, 10, 9, 11, 12, 16, 17 }
    -- the requirement's class names and paths by the row's cells 13 (class) and 14 (path)
    local CLASSES = { "Warrior", "Rogue", "Mage", "Poet", "Archer" }
    local PATHS = { "W", "R", "M", "P", "A" }
    local RANKS = { "Il San", "Ee San", "Sam San", "Sa San" }

    --- PopulateItemData (0x004CCCA0) for the item's key: the description (cell 0 of the first ItemHelp0-8 that has it), then
    --- a price (the first ItemInfo0-8 that has it: its row, cell 1 with commas, labelled "Value "), else the first CharicInfo
    --- table's row (the labels above, cell 2 as "cur/max (pct%) ", the bonuses with a "+"), else "Value " "0" and, worn,
    --- "Durability " and its value.
    local function populate(key, durability)
        local d = { labels = {}, values = {}, description = "" }
        for i = 0, 19 do d.labels[i], d.values[i] = " ", "" end
        d.labels[0], d.labels[13], d.labels[14], d.labels[15] = "", "", "", ""
        for i = 0, 8 do
            local row = H:GetMetaRow("ItemHelp" .. i, key)
            if row and (row[1] or "") ~= "" then
                d.description = row[1]
                break
            end
        end
        local function cells(row) for i = 0, 19 do d.values[i] = row[i + 1] or "" end end
        for i = 0, 8 do
            local row = H:GetMetaRow("ItemInfo" .. i, key)
            if row and (row[1] or "") ~= "" then
                cells(row)
                d.labels[1], d.values[1] = "Value ", commas(d.values[1])
                return d
            end
        end
        local i = 0
        while H:HasMetaTable("CharicInfo" .. i) do
            local row = H:GetMetaRow("CharicInfo" .. i, key)
            if row and (row[1] or "") ~= "" then
                d.table = true
                for k, label in pairs(LABELS) do d.labels[k] = label end
                cells(row)
                local max = wtol(d.values[2])
                d.values[2] = string.format("%d/%d (%d%%) ", durability, max, max == 0 and 0 or div(durability * 100, max))
                for _, k in ipairs(BONUS) do
                    local bonus = d.values[k] ~= "0" and wtol(d.values[k]) or 0
                    if bonus > 0 then d.values[k] = "+" .. bonus end
                end
                return d
            end
            i = i + 1
        end
        d.labels[1], d.values[1] = "Value ", "0"
        if durability > 0 then d.labels[2], d.values[2] = "Durability ", tostring(durability) end
        return d
    end

    local function build()
        local f = CreateFrame("Frame", ctx.name, UIParent)
        f:SetFrameStrata("TOOLTIP")
        -- filled 0x97 and framed in 0x80 (OnPaint), composed at the pane's alpha 0.2 (mode 2) as the tip is (hud.lua)
        f.fill = S.Fill(f:CreateTexture(nil, "BACKGROUND"), ctx.fill or 0x97, 26 / 32)
        f.fill:SetAllPoints(f)
        for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT", true },
                             { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
            local t = S.Fill(f:CreateTexture(nil, "BORDER"), 0x80)
            t:SetPoint(e[1], f, e[1], 0, 0)
            t:SetPoint(e[2], f, e[2], 0, 0)
            if e[3] then t:SetWidth(1) else t:SetHeight(1) end
        end
        f.texts = {}
        TK.Game.ItemHelp.Attach(f, ctx.name .. "Catcher")
        f:Hide()
        return f
    end

    --- Text n of the box at its pen (x, baseline) in colour.
    local function pen(n, text, x, baseline, colour)
        local fs = box.texts[n] or box:CreateFontString(nil, "OVERLAY")
        box.texts[n] = fs
        S.Text(fs, colour)
        fs:SetWordWrap(false)
        fs:SetJustifyH("LEFT")
        fs:SetText(text or "")
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", box, "TOPLEFT", x, -(baseline - 12 + 1))
        fs:Show()
    end

    --- Shows the item box for owner's right press at the pointer (ItemHelpPane's constructor, owner the self look:
    --- GeneralPurposePanel child 0 or 2): the inventory/worn key, name, durability, protection and optional inventory owner.
    --- Replaces the one local sheet; its input and timer are the game layer's.
    function B.Show(owner, key, name, durability, protection, itemOwner)
        box = box or build()
        durability = math.floor(durability or 0)
        protection = protection or 0
        local d = populate(key ~= "" and key or name, durability)
        local desc = d.description
        local hasDesc = desc ~= "" and desc ~= " "
        local l180 = #wrap(desc, 180)
        -- the size (the constructor): the lines, the content's width (the description's to 180, the name's + 1, the rows')
        local lines = hasDesc and 2 + l180 or 1
        local cw = math.max(math.min(width(desc), 180), width(name) + 1)
        if not d.table then
            if durability > 0 then
                lines = lines + 4
                cw = math.max(cw, 156)
            else
                lines = lines + 2
                cw = math.max(cw, width(d.values[1]) + 6 + width(d.labels[1]))
            end
        else
            lines = lines + 1
            for i = 2, 19 do
                local v = d.values[i]
                if i ~= 13 and i ~= 14 and i ~= 15 and v ~= "0" and v ~= "" then
                    lines = lines + 1
                    cw = math.max(cw, width(v) + 6 + width(d.labels[i]))
                end
            end
            lines = lines + 2
            if wtol(d.values[14]) == 0 or wtol(d.values[13]) == 0 then cw = math.max(cw, 156) end
        end
        itemOwner = itemOwner or ""
        if protection > 0 then lines = lines + 1 end
        local w, h = cw + 20, 13 * lines + 19
        if hasDesc then h = h - (l180 - 1) end
        -- 4a's content-sized sheet uses native font advances and 12/13-pixel lines (constructor 0x004C82D0,
        -- OnPaint 0x004C8BD0). At 640 the game art shrinks, but these dense rows retain their readable native size.
        -- Placement converts the owner's bounds/pointer into this drawing scale; its catcher and timer are unchanged.
        local scale = math.max(owner:GetEffectiveScale(), 1 / TK.UIScale())
        Help.PlaceBox(box, owner, w, h, scale)

        -- the paint (OnPaint 0x004C8BD0): the name twice a pixel apart, centred, its pen at 22; the description centred on
        -- 12-pixel lines from 36 down to the box's bottom - 10; the rows 13 apart from 11 less the description's lines at 180
        local n = 0
        local function text(t, x, baseline, colour)
            n = n + 1
            pen(n, t, x, baseline, colour)
        end
        local right = w - 10
        local cx = div(10 + right, 2)
        local wn = width(name)
        text(name, div(10 + right, 2) - div(wn, 2), 22, 0x8F)
        text(name, div(11 + right + 1, 2) - div(wn, 2), 22, 0x8F)
        local row = 2
        if hasDesc then
            local y = 36
            for _, line in ipairs(wrap(desc, cw)) do
                if y > h - 10 then break end
                y = y + 12
                text(line, cx - div(width(line), 2), y, 0x8F)
            end
            row = #wrap(desc, cw) + 3
        end
        local top = 11 - l180
        --- parts ({ text, colour }) centred together on cx, each in its own rectangle as 4a cuts them (CENTRED_ROW,
        --- REQUIREMENT_ROW), at row r
        local function centred(parts, r)
            local total, widths = 0, {}
            for i, p in ipairs(parts) do
                widths[i] = width(p[1])
                total = total + widths[i]
            end
            local before = 0
            for i, p in ipairs(parts) do
                local l = cx - div(total - 2 * before, 2)
                before = before + widths[i]
                local r2 = cx - div(total - 2 * before, 2)
                text(p[1], div(l + r2, 2) - div(widths[i], 2), top + 13 * r + 12, p[2])
            end
        end
        if not d.table then
            if durability > 0 then
                centred({ { d.labels[2], 0x8F }, { d.values[2], 0x0E } }, row)
                row = row + 1
                centred({ { d.labels[1], 0x8F }, { d.values[1], 0x0E } }, row)
            else
                -- right-aligned at the content's right edge
                local lw, vw = width(d.labels[1]), width(d.values[1])
                text(d.labels[1], div(2 * right - 2 * vw - lw, 2) - div(lw, 2), top + 13 * row + 12, 0x8F)
                text(d.values[1], div(2 * right - vw, 2) - div(vw, 2), top + 13 * row + 12, 0x0E)
            end
        else
            centred({ { d.labels[2], 0x8F }, { d.values[2], 0x0E } }, row)
            -- the damage rows from the durability row's left, left-aligned
            local left = cx - div(width(d.labels[2]) + width(d.values[2]), 2)
            row = row + 1
            for _, k in ipairs({ 18, 19 }) do
                if d.values[k] ~= "0" then
                    text(d.labels[k], left, top + 13 * row + 12, 0x8F)
                    text(d.values[k], left + width(d.labels[k]), top + 13 * row + 12, 0x0E)
                    row = row + 1
                end
            end
            for _, k in ipairs(BONUS) do
                if d.values[k] ~= "0" then
                    centred({ { d.labels[k], 0x8F }, { d.values[k], 0x0E } }, row)
                    row = row + 1
                end
            end
            if itemOwner ~= "" then
                -- 4a OnPaint 0x004C8BD0: the inventory record's owner comes after the bonus rows, before protection.
                centred({ { "Owner ", 0x8F }, { itemOwner, 0x0E } }, row)
                row = row + 1
            end
            row = row + 1
            if protection > 0 then
                local t = string.format("PROTECTED (%d)", protection)
                text(t, cx - div(width(t), 2), top + 13 * row + 12, 12)
                row = row + 1
            end
            local class, path = wtol(d.values[13]), wtol(d.values[14])
            local name13 = class == 0 and path == 0 and "Any Class" or path == 0 and CLASSES[class] or nil
            if name13 then
                centred({ { name13, 10 }, { "   Level ", 0x8F }, { d.values[15], 0x0E }, { " Req ", 0x8F } }, row)
            elseif CLASSES[class] and RANKS[path] then
                local t = RANKS[path] .. " (" .. PATHS[class] .. ")"
                text(t, cx - div(width(t), 2), top + 13 * row + 12, 10)
            end
        end
        for i = n + 1, #box.texts do box.texts[i]:Hide() end
        TK.Game.ItemHelp.Show(box)
    end

    --- Whether the box shows (SelfLookPane's hover tip waits for none: OnTimer 0x00569860).
    function B.Shown() return box ~= nil and box:IsShown() end

    return B
end
