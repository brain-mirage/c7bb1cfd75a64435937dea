-- s6-rules-dialogs round 8: D-33, the collection album (CollectionDialogPane). The volume's title (CLTNAME.EPF, frame
-- the volume), the progress it opened with ("collected/total (percent%)"), and six entries a page: a collected entry's
-- picture (CLTVOL<volume>.EPF, frame its index), number, name, label and description; an entry not collected shows the
-- unknown icon (CLTICON.EPF 0) and question marks; past the volume's last entry the empty icon (CLTICON.EPF 1).
-- Previous (1), Close (2: Enter and Esc), Next (3); paging sends nothing.
--
-- s6-modular-g (interfaces): the window's size, its cards and where they sit are the look's (C.look.Album); this
-- file keeps what the album shows and does.
-- Wire: CollectionDialogPane::OnControlCommand 0x0048CFB0 by these indexes (Close's 2 the one the model answers);
-- changing an index changes what the server sees.

local C = TK.GetComponent("dialogs")
local W = TK.UI
local K = C.kit

local Album = { look = "Album" }

--- A picture of the album's art in a card's texture, as large as the look lets it (L.picture square); a dark square
--- without the packs.
local function picture(tex, file, frame, palette)
    local size = C.look.Album.picture
    local key, w, h = TK.Art.Image(file, frame, palette)
    if not key then
        tex:SetTexture("tk:white")
        tex:SetVertexColor(0.12, 0.12, 0.14, 1)
        tex:SetSize(size, size)
        return
    end
    tex:SetTexture(key)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:SetSize(math.min(w, size), math.min(h, size))
end

function Album.build()
    local L = C.look.Album
    local win = K.Window(L.width, L.height, "")
    win.volume = win:CreateTexture(nil, "ARTWORK")
    win.progress = W.Label(win, "", 12, W.white)
    win.cards = {}
    for i = 1, 6 do win.cards[i] = L.card(win, i) end
    win.previous = K.Button(win, 1, "Previous", L.button)
    win.close = K.Button(win, 2, "Close", L.button)
    win.nextButton = K.Button(win, 3, "Next", L.button)
    L.place(win)
    return win
end

function Album.update(win, view)
    local c = view.contents
    local volume = c.volume or 0
    local key, w, h = TK.Art.Image("CLTNAME.EPF", volume, "CLTNAME.PAL")
    if key then
        win.volume:SetTexture(key)
        win.volume:SetSize(w, h)
        win.volume:Show()
        win.title:SetText("")
    else
        win.volume:Hide()
        win.title:SetText("Collection: volume " .. volume)
    end
    local p = c.progress or {}
    local collected, total = p[1] or 0, p[2] or 0
    win.progress:SetText(string.format("%d/%d (%d%%)", collected, total, total > 0 and math.floor(100 * collected / total) or 0))
    local entries = c.entries or {}
    for i, card in ipairs(win.cards) do
        local e = entries[i]
        card.name:SetText("")
        card.number:SetText("")
        card.label:SetText("")
        card.desc:SetText("")
        if type(e) ~= "table" then
            picture(card.pic, "CLTICON.EPF", 1, "CLTICON.PAL")
        else
            card.number:SetText(string.format("%2d", (e[1] or 0) + 1))
            if e[2] then
                picture(card.pic, "CLTVOL" .. volume .. ".EPF", e[1] or 0, "CLTVOL" .. volume .. ".PAL")
                card.name:SetText(e[3] or "")
                card.label:SetText(e[4] or "")
                -- The original's text breaks a line at the two characters \ and n.
                card.desc:SetText(((e[5] or ""):gsub("\\n", "\n")))
            else
                picture(card.pic, "CLTICON.EPF", 0, "CLTICON.PAL")
                card.name:SetText(string.rep("?", 15))
                card.label:SetText(string.rep("?", 10))
            end
        end
    end
    -- s6-modular-g (interfaces, round 13): what a look draws of its own (7.x's: the title's place, the progress bar, the
    -- numbers drawn twice); drawing only
    if C.look.Album.fill then C.look.Album.fill(win, c) end
end

C.renderers.CollectionDialogPane = Album
