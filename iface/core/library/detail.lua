-- The Library pages' detail view (s6-library-pages): a scrolling column of headings, wrapped lines and rows of
-- columns, each row with an optional picture, laid out top-down and reused from a pool each time the page is shown. The
-- Monsters, Items and NPCs pages put their drops, shops, holders and places in one. Every text shown is also kept for
-- the page's texts (L:Say). Drawing only: nothing is read or sent here.

local W = TK.UI
local L = TK.Library

local GOLD_SUB = { 0.9, 0.78, 0.45 }
local DIM = { 0.62, 0.62, 0.66 }
local LINK = L.LINK -- FOR s6-library-pages (s6-library round 19, cross-links; round 23: library.lua's link helpers)
local ROW = 26
-- A table's rows alternate between two close opaque charcoals (Astra's design note, round 3), quiet beside the window's
-- charcoal fill so the names and figures carry the row.
local STRIPES = { { 0.13, 0.135, 0.15, 1 }, { 0.16, 0.165, 0.18, 1 } }

--- A detail view filling parent below top (pixels from parent's top).
function TK.LibraryDetail(parent, top)
    local d = { labels = {}, rows = {}, hits = {}, nLabels = 0, nRows = 0, nHits = 0 }
    local sf, content = W.ScrollArea(parent)
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(top or 0))
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 0)
    sf.wheelStep = ROW * 3
    d.sf, d.content = sf, content

    local function label(size, colour)
        d.nLabels = d.nLabels + 1
        local fs = d.labels[d.nLabels]
        if not fs then
            fs = W.Label(content, "", size, colour, "LEFT")
            d.labels[d.nLabels] = fs
        end
        fs:SetFont(size, "")
        W.Color(fs, colour)
        fs:SetWordWrap(true)
        fs:ClearAllPoints()
        fs:Show()
        return fs
    end

    --- FOR s6-library-pages (s6-library round 19, cross-links): the next link area of the pool (L.LinkArea, made the
    --- first time), for a line's text or a row; round 23: placed by library.lua's helpers.
    local function link()
        d.nHits = d.nHits + 1
        local h = d.hits[d.nHits]
        if not h then
            h = L.LinkArea(content)
            d.hits[d.nHits] = h
        end
        return h
    end

    --- A new layout of the entry key names (the page's selected entry): the scroll goes back to the top only for another
    --- entry, so the window's refresh in play leaves where the player scrolled to (Astra's P2 on round 1).
    function d:Begin(key)
        for _, fs in ipairs(self.labels) do fs:Hide() end
        for _, r in ipairs(self.rows) do r:Hide() end
        for _, h in ipairs(self.hits) do h:Hide() end -- s6-library round 19
        self.nLabels, self.nRows, self.nHits, self.y = 0, 0, 0, -4
        self.width = math.max(100, sf:GetWidth() > 0 and sf:GetWidth() or parent:GetWidth() - 8)
        if key ~= self.key then sf:SetVerticalScroll(0) end
        self.key = key
    end

    --- A sub-heading, a little space above it.
    function d:Header(text)
        self.y = self.y - (self.y < -4 and 10 or 0)
        local fs = label(13, GOLD_SUB)
        fs:SetWidth(self.width - 8)
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, self.y)
        L:Say(fs, text)
        self.y = self.y - fs:GetStringHeight() - 6
    end

    --- A wrapped line ("dim" or "note" for those colours), indented. s6-library round 19: with go, a link (its own colour;
    --- a click on its text runs go).
    function d:Text(text, kind, indent, go)
        local colour = go and LINK or kind == "dim" and DIM or kind == "note" and { 1, 0.6, 0.35 } or W.white
        local fs = label(12, colour)
        local width = self.width - 8 - (indent or 0)
        fs:SetWidth(width)
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", 4 + (indent or 0), self.y)
        L:Say(fs, text)
        if go then L.LinkOver(link(), fs, go, width) end
        self.y = self.y - fs:GetStringHeight() - 4
    end

    --- A row of columns: texts at the x positions in xs (from the row's left, after its picture), with the picture
    --- image() gives (key, width, height) when image is given. s6-library round 19: with go, a link (its first column in
    --- the link's colour; a click on the row runs go).
    function d:Row(texts, xs, image, go)
        self.nRows = self.nRows + 1
        local r = self.rows[self.nRows]
        if not r then
            r = CreateFrame("Frame", nil, content)
            r:SetHeight(ROW)
            r.bg = r:CreateTexture(nil, "BACKGROUND")
            r.bg:SetAllPoints(r)
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.cols = {}
            self.rows[self.nRows] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", content, "TOPLEFT", 4, self.y)
        r:SetWidth(self.width - 8)
        r.bg:SetColorTexture(table.unpack(STRIPES[self.nRows % 2 + 1]))
        local x = 6
        r.icon:Hide()
        if image then
            local key, w, h = image()
            if key then
                TK.Art.Place(r.icon, r, key, w, h, ROW - 4)
                r.icon:ClearAllPoints()
                r.icon:SetPoint("CENTER", r, "LEFT", x + (ROW - 4) / 2, 0)
                r.icon:Show()
            end
            x = x + ROW + 2
        end
        local shown = {}
        for i, text in ipairs(texts) do
            local fs = r.cols[i]
            if not fs then
                fs = W.Label(r, "", 12, W.white, "LEFT")
                r.cols[i] = fs
            end
            local left = x + (xs[i] or 0)
            local right = xs[i + 1] and (x + xs[i + 1] - 8) or (self.width - 12)
            fs:SetWidth(math.max(10, right - left))
            fs:SetWordWrap(false)
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", r, "LEFT", left, 0)
            fs:SetText(text)
            W.Color(fs, go and i == 1 and LINK or W.white) -- s6-library round 19: a link's name
            fs:Show()
            shown[#shown + 1] = text
        end
        for i = #texts + 1, #r.cols do r.cols[i]:Hide() end
        L.texts[#L.texts + 1] = table.concat(shown, "  ")
        r:Show()
        if go then L.PlaceLink(link(), r, self.width - 8, ROW, go, texts[1]) end
        self.y = self.y - ROW
    end

    function d:End()
        content:SetSize(self.width, -self.y + 8)
        sf.Refresh()
    end

    return d
end

--- A picture box: a dark square of size box, its picture centred (box:SetPicture, TK.LibraryPictures.Show's kinds).
function TK.LibraryPictureBox(parent, box)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(box, box)
    f:SetBackdrop({ bg = { 0.11, 0.11, 0.13, 1 }, edge = W.innerEdge, bgFile = "tk:white" })
    f.picture = f:CreateTexture(nil, "ARTWORK")
    f.none = W.Label(f, "", 11, DIM)
    f.none:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.none:SetWidth(box - 8)
    f.none:SetWordWrap(true)
    --- The picture of kind (TK.LibraryPictures.Picture's), or "no picture" when there is none. s6-library round 25 (the
    --- owner's request: "a static graphic of the mob"): a creature stands still, no longer walking in place.
    function f:SetPicture(kind, a, b, width, height)
        local shown = kind ~= nil and TK.LibraryPictures.Show(self.picture, self, box - 8, kind, a, b, width, height)
        if not shown then self.picture:Hide() end
        self.none:SetText((shown or kind == nil) and "" or "No picture (no art packs)")
    end
    return f
end
