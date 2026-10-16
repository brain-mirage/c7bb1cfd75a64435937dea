-- The Library window's pages of lines (s6-library rounds 2-12; moved out of library.lua by s6-library-pages): a page
-- adds its lines (a header, a sub-heading, text, dim text, a note), a section's line may carry its Clear, and the lines
-- are laid out in the window's scroll area. The Spells, Maps and Players pages and the characters' History are lines.
-- Nothing here reads the Library itself or sends anything; a Clear asks the C# side to clear the server's records.

local W = TK.UI
local H = __tk
local L = TK.Library

local X = {}
L.Lines = X

X.OFF = "Tracking off (Settings, Library)." -- s6-library round 18 (the owner: no explanations on the page)

function X.thousands(n) return TK.Util.FormatNumber(math.floor(tonumber(n) or 0)) end

--- s6-library round 15: an amount range, "3" or "1-3" (the drops' and the server's drop tables' amounts).
function X.range(least, most) return least == most and X.thousands(most) or (X.thousands(least) .. "-" .. X.thousands(most)) end

local lines = {}   -- { text, kind, indent, clear, go, tip }

--- A new page of lines.
function X.Begin() lines = {} end

function X.Count() return #lines end

--- A line; s6-library round 21 (links between the pages): with go, a link (L.LINK's colour; a click on its text runs go,
--- as detail.lua's lines do). Round 24: with tip, the pointer on its text shows it (L.ItemTip's).
function X.add(text, kind, indent, go, tip)
    local l = { text = text, kind = kind or "text", indent = indent or 0, go = go, tip = tip }
    lines[#lines + 1] = l
    return l
end

-- Round 4 (review r2 finding 8; head note 1): a section's Clear, beside its heading, as on the Library settings page: the
-- first press asks ("Confirm Clear"), the second deletes what those trackers recorded for this server (a character's
-- section for that character only). The switches stay; they change only on the login screen's Settings.
local CLEAR_WIDTH = 110

--- The section line's Clear: key names it (one waits for its confirmation at a time), ids are the trackers it clears;
--- label is the button's text when it is not "Clear" (the maps page's "Clear Map Data", as on the settings page).
function X.clear(line, key, ids, character, label)
    line.clear = { key = key, ids = ids, character = character or "", label = label or "Clear",
        width = label and CLEAR_WIDTH + 70 or CLEAR_WIDTH }
    return line
end

--- The trackers of a settings group that record something (the maps page's Clear Map Data clears them all).
function X.groupIds(group)
    local ids = {}
    for _, t in ipairs(H:GetLibraryTrackers(L.server)) do
        if t.group == group and t.records then ids[#ids + 1] = t.id end
    end
    return ids
end

local function clearClicked(c)
    if L.pending ~= c.key then
        L.pending = c.key
    else
        L.pending = nil
        H:ClearLibrary(L.server, table.concat(c.ids, ","), c.character)
    end
    L:Refresh()
end

--- s6-library-pages: a Clear button of a page that is not lines (a monster's drops, an NPC's shops, a legend), asking as
--- the lines' Clear does; L.clears[key] is it (tests). Set it again with X.SetClear when what it clears changes.
function X.ClearButton(parent, width)
    local b = W.Button(parent, "", width or CLEAR_WIDTH, 20)
    b:SetScript("OnClick", function(self) if self.clear then clearClicked(self.clear) end end)
    return b
end

function X.SetClear(b, key, ids, character, label)
    b.clear = { key = key, ids = ids, character = character or "", label = label or "Clear" }
    b:SetText(L.pending == key and ("Confirm " .. b.clear.label) or b.clear.label)
    L.clears[key] = b
end

local KIND = {
    header = { size = 14, colour = W.gold, gap = 8 },
    sub = { size = 13, colour = { 0.9, 0.78, 0.45 }, gap = 4 },
    text = { size = 12, colour = W.white, gap = 0 },
    dim = { size = 12, colour = { 0.62, 0.62, 0.66 }, gap = 0 },
    note = { size = 12, colour = { 1, 0.6, 0.35 }, gap = 0 },
}

--- A line's Clear button, beside it at y: the n-th of the content's buttons.
local function placeClear(content, n, c, y)
    local b = content.clears[n]
    if not b then
        b = W.Button(content, "", CLEAR_WIDTH, 20)
        content.clears[n] = b
    end
    b:SetWidth(c.width)
    b:SetText(L.pending == c.key and ("Confirm " .. c.label) or c.label)
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, y + 2)
    b:SetScript("OnClick", function() clearClicked(c) end)
    b:Show()
    L.clears[n] = b
    L.clears[c.key] = b
end

-- Round 12: a page longer than this draws only the lines in view. A Library filled from a server's files has some
-- 15,000 lines on its maps page, which took seconds to lay out line by line. s6-library-pages (Astra's P2 on round 12):
-- its lines still wrap; a line long enough to wrap is measured once (a short one is one row), so the rows' heights are
-- known without laying out every line.
local VIRTUAL_LINES = 400
local CHAR_WIDTH = 7 -- wider than a 12-point character on average: a line shorter than its width in these never wraps

--- Round 21: a link line's click area over its text (fs), the n-th of the content's (round 23: library.lua's helpers;
--- round 24: with its tip).
local function placeLink(content, n, fs, go, tip)
    local b = content.links[n]
    if not b then
        b = L.LinkArea(content)
        content.links[n] = b
    end
    L.LinkOver(b, fs, go, fs:GetWidth(), tip)
end

--- s6-optimize: one line's label, the n-th of the pool (made the first time), styled for its kind (a link's colour,
--- round 21), placed at y with its Clear button and its link; the virtual and the full paths both draw with it. Returns
--- the label and the content's link count after it.
local function drawLine(content, pool, n, l, width, y, links)
    local k = KIND[l.kind] or KIND.text
    local fs = pool[n]
    if not fs then
        fs = W.Label(content, "", 12, W.white, "LEFT")
        pool[n] = fs
    end
    local colour = l.go and L.LINK or k.colour
    fs:SetWordWrap(true)
    fs:SetFont(k.size, "")
    fs:SetTextColor(colour[1], colour[2], colour[3], 1)
    fs:SetWidth(width - 16 - l.indent - (l.clear and l.clear.width + 8 or 0))
    fs:SetText(l.text)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 8 + l.indent, y)
    fs:Show()
    if l.clear then placeClear(content, #L.clears + 1, l.clear, y) end
    if l.go or l.tip then links = links + 1; placeLink(content, links, fs, l.go, l.tip) end
    return fs, links
end

--- The lines of a long page that are in view (the scroll's position), from the pool; drawn again when it moves.
function X.drawVisible(content)
    local v = content.virtual
    local top, height = content.scroll:GetVerticalScroll(), content.scroll:GetHeight()
    if v.drawn == top and v.height == height then return end
    v.drawn, v.height = top, height
    for _, fs in ipairs(v.pool) do fs:Hide() end
    for _, b in ipairs(content.clears) do b:Hide() end
    for _, b in ipairs(content.links) do b:Hide() end -- round 21
    L.clears = {}
    local shown = v.lines
    local first, last = 1, #shown
    while first < last do -- the first line whose row reaches the view
        local mid = math.floor((first + last) / 2)
        if -v.tops[mid] + v.rows[mid] < top then first = mid + 1 else last = mid end
    end
    local n, links = 0, 0
    for i = first, #shown do
        if -v.tops[i] > top + height then break end
        n = n + 1
        links = select(2, drawLine(content, v.pool, n, shown[i], v.width, v.tops[i], links))
    end
end

--- The page's lines laid out in content (width wide), from the pool of labels; L.texts gets their texts.
function X.render(content, pool, width)
    for _, fs in ipairs(pool) do fs:Hide() end
    content.clears = content.clears or {}
    for _, b in ipairs(content.clears) do b:Hide() end
    content.links = content.links or {} -- round 21
    for _, b in ipairs(content.links) do b:Hide() end
    L.texts = {}
    if #lines > VIRTUAL_LINES then
        local tops, rows, y = {}, {}, -6
        local measure = content.measure
        if not measure then
            measure = W.Label(content, "", 12, W.white, "LEFT")
            measure:SetWordWrap(true)
            measure:Hide()
            content.measure = measure
        end
        for i, l in ipairs(lines) do
            local k = KIND[l.kind] or KIND.text
            local w = width - 16 - l.indent - (l.clear and l.clear.width + 8 or 0)
            local h = k.size + 3
            if #l.text * CHAR_WIDTH > w then
                measure:SetFont(k.size, "")
                measure:SetWidth(w)
                measure:SetText(l.text)
                h = measure:GetStringHeight() + 3
            end
            y = y - k.gap
            tops[i], rows[i] = y, math.max(l.clear and 22 or 15, h)
            y = y - rows[i]
            L.texts[i] = l.text
        end
        content:SetSize(width, -y + 8)
        content.virtual = { lines = lines, tops = tops, rows = rows, width = width, pool = pool }
        X.drawVisible(content)
        return
    end
    content.virtual = nil
    local y, links = -6, 0
    for i, l in ipairs(lines) do
        y = y - (KIND[l.kind] or KIND.text).gap
        local fs
        fs, links = drawLine(content, pool, i, l, width, y, links)
        y = y - math.max(l.clear and 22 or 15, fs:GetStringHeight() + 3)
        L.texts[#L.texts + 1] = l.text
    end
    content:SetSize(width, -y + 8)
end

-- ----- what the pages say -----

--- The note that a tracker is off for this server (what was recorded before still shows).
function X.offNote(id) if L.data and L.data.on and not L.data.on[id] then X.add(X.OFF, "note") end end

function X.seenText(has, when, verb) return has and ((verb or "last seen") .. " " .. when) or "not seen yet" end

-- Round 11: when an entry was seen, or that it came from the server's own files (tools/library-seed; LuaApi's LibraryTime).
X.FROM_FILES = "from the server's files"
function X.stamp(when, verb) return when == X.FROM_FILES and when or ((verb or "last seen") .. " " .. when) end

--- s6-library round 18 (the owner: no text repeated on every row): a list row's "  (last seen ...)", and nothing for an
--- entry from the server's files (the page's own line says where it came from).
function X.rowStamp(when, verb) return when == X.FROM_FILES and "" or ("  (" .. X.stamp(when, verb) .. ")") end

function X.itemLine(it)
    local n = tonumber(it.count) or 0
    return it.name .. (n > 1 and ("  x" .. X.thousands(n)) or "")
end
