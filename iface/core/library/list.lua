-- The Library window's left column (s6-library-pages, the owner's refinement pass 2026-10-04): a list of names, each
-- with an optional line under it and an optional picture, that makes rows only for what is in view (a Library filled
-- from a server's files lists thousands of items) and makes them again only when the list or its scroll changes. A
-- click selects a row; an indented row is a sub-page of the one above it (the characters' Overview, History...).
-- Built from TK.UI's scroll area; nothing here reads the Library or sends anything.

local W = TK.UI

local ROW = 34       -- a row's height: a 13-point name and an 11-point line under it, with room around them
local PICTURE = 26   -- a row's picture, at most this square

--- A list in parent; onClick(row) runs when a row is clicked. list:SetRows(rows, selected, ...) shows the rows ({ key,
--- name, sub, indent }, the selected one's key highlighted), each with the picture image(row) gives (key, width, height,
--- or nil) when there is an image function; list:Select(key) moves the highlight.
function TK.LibraryList(parent, onClick)
    local list = { rows = {}, cells = {}, selected = nil }
    local sf, content = W.ScrollArea(parent)
    sf.wheelStep = ROW * 3
    list.sf, list.content = sf, content
    local empty = W.Label(content, "", 12, { 0.62, 0.62, 0.66 }, "LEFT")
    empty:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -6)
    -- s6-library round 18 (QA's build-40 pass: the text was cut at the column's edge; FOR s6-library-pages): it wraps
    -- inside the column (SetRows gives it the column's width; a font string wraps at its own width).
    empty:SetWordWrap(true)
    list.empty = empty

    local function cell(i)
        local c = list.cells[i]
        if c then return c end
        c = CreateFrame("Button", nil, content)
        c:SetHeight(ROW)
        c.bg = c:CreateTexture(nil, "BACKGROUND")
        c.bg:SetAllPoints(c)
        local hl = c:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(c)
        hl:SetColorTexture(1, 1, 1, 0.07)
        c.picture = c:CreateTexture(nil, "ARTWORK")
        c.name = W.Label(c, "", 13, W.white, "LEFT")
        c.sub = W.Label(c, "", 11, { 0.65, 0.65, 0.7 }, "LEFT")
        c:SetScript("OnClick", function(self) if self.row then onClick(self.row) end end)
        list.cells[i] = c
        return c
    end

    --- The rows in view drawn into the cells (again only when the scroll or the rows changed).
    function list:Draw(force)
        local top, height = sf:GetVerticalScroll(), sf:GetHeight()
        if not force and self.drawnTop == top and self.drawnHeight == height then return end
        self.drawnTop, self.drawnHeight = top, height
        local width = sf:GetWidth()
        local first = math.max(1, math.floor(top / ROW) + 1)
        local last = math.min(#self.rows, math.floor((top + height) / ROW) + 1)
        local n = 0
        for i = first, last do
            n = n + 1
            local r, c = self.rows[i], cell(n)
            local indent = r.indent or 0
            c.row = r
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW)
            c:SetWidth(math.max(1, width))
            local selected = r.key == self.selected
            c.bg:SetColorTexture(selected and 0.35 or 0, selected and 0.28 or 0, selected and 0.1 or 0, selected and 0.9 or 0)
            local x = 6 + indent
            c.picture:Hide()
            if self.image then
                local key, w, h = self.image(r)
                if key then
                    TK.Art.Place(c.picture, c, key, w, h, PICTURE)
                    c.picture:ClearAllPoints()
                    c.picture:SetPoint("CENTER", c, "LEFT", x + PICTURE / 2, 0)
                    c.picture:Show()
                end
                x = x + PICTURE + 6
            end
            c.name:ClearAllPoints()
            c.name:SetWidth(math.max(1, width - x - 4))
            c.name:SetText(r.name or "")
            W.Color(c.name, selected and W.gold or (indent > 0 and { 0.9, 0.78, 0.45 } or W.white))
            local sub = r.sub or ""
            c.sub:SetText(sub)
            c.sub:SetWidth(math.max(1, width - x - 4))
            if sub ~= "" then
                c.name:SetPoint("TOPLEFT", c, "TOPLEFT", x, -3)
                c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -1)
                c.sub:Show()
            else
                c.name:SetPoint("LEFT", c, "LEFT", x, 0)
                c.sub:Hide()
            end
            c:Show()
        end
        for i = n + 1, #self.cells do
            self.cells[i]:Hide()
            self.cells[i].row = nil
        end
    end

    --- New rows, the selected key, what an empty list says, and the rows' pictures (image, or nil); the scroll goes back
    --- to the top unless keepScroll (the same list read again).
    function list:SetRows(rows, selected, emptyText, keepScroll, image)
        if not keepScroll then sf:SetVerticalScroll(0) end
        self.rows, self.selected, self.image = rows, selected, image
        content:SetSize(math.max(1, sf:GetWidth()), math.max(1, #rows * ROW))
        empty:SetWidth(math.max(1, sf:GetWidth() - 12)) -- s6-library round 18: the column's width, 6 each side
        empty:SetText(#rows == 0 and (emptyText or "") or "")
        self:Draw(true)
        sf.Refresh()
    end

    function list:Select(key)
        self.selected = key
        self:Draw(true)
    end

    --- Brings the selected row into view.
    function list:ShowSelected()
        for i, r in ipairs(self.rows) do
            if r.key == self.selected then
                local top, h = (i - 1) * ROW, sf:GetHeight()
                local now = sf:GetVerticalScroll()
                if top < now or top + ROW > now + h then sf:SetVerticalScroll(math.max(0, top - h / 2)) end
                self:Draw(true)
                sf.Refresh()
                return
            end
        end
    end

    content:SetScript("OnUpdate", function() list:Draw(false) end)
    return list
end
