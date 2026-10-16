-- The spell icon editor (s6-spell-icons; the owner's request of 2026-10-04, docs/development/jobs/s6-spell-icons/DESIGN.md
-- section 5): opened by a right click on a spell in the spell book. On the left the categories (General, Basic, Effects,
-- Tiles, Creatures, Icons); on the right the category's pictures in the picture viewer (core/viewer.lua). Clicking a
-- picture chooses it for the spell in the scope the "Save to" drop-down names (Per Server by default; Character over
-- Server over Global), at once, and the bars and the book follow; the viewer's detail part then trims an animation and
-- holds "Always animate this spell".
--
-- Drawing only: nothing here is sent. The choices are files (TK.Core.Objects.SpellIconStore, through __tk's
-- Get/SetSpellIconEntry), by the spell's name.

local H = __tk
local W = TK.UI
local Icons = require("data.spell_icons")

local E = { spell = nil, scope = "server", category = "general" }
TK.SpellIconEditor = E

local WIDTH, HEIGHT, LIST_W, TOP = 700, 480, 120, 76
local VIEW_W, VIEW_H = WIDTH - LIST_W - 36, HEIGHT - TOP - 52

local CATEGORIES = {
    { id = "general", name = "General" },
    { id = "basic", name = "Basic" },
    { id = "effects", name = "Effects" },
    { id = "tiles", name = "Tiles" },
    { id = "objects", name = "Objects", under = true }, -- round 3: the map's trees, walls and signs, a part of Tiles
    { id = "creatures", name = "Creatures" },
    { id = "icons", name = "Icons" },
}

local SCOPES = {
    { value = "global", text = "Global" },
    { value = "server", text = "Per Server" },
    { value = "character", text = "Character" },
}

--- What decides the icon now, as the General page and the top line name it.
local SOURCES = {
    character = "this character's choice", server = "this server's choice", global = "the global choice",
    pack = "the server pack", ours = "the client's built-in table", learned = "the learned effect",
    [""] = "nothing chosen: the lettered button",
}

local frame

--- The character in the world (the editor opens from the book, so in the world).
local function who() return TK.Characters.ref or "" end

--- The spell's entry in the scope being edited, or nil.
function E:Entry() return H:GetSpellIconEntry(self.scope, self.spell, who()) end

--- Writes the spell's entry in the scope (nil: clears it); the bars, the book and the cursor redraw their icons.
function E:Choose(entry)
    local ok, problem = H:SetSpellIconEntry(self.scope, self.spell, who(), entry)
    if not ok then
        UIErrorsFrame:AddMessage("The icon was not saved: " .. tostring(problem), 1, 0.3, 0.3)
        return false
    end
    TK.FireEvent("TK_SPELL_ICONS_CHANGED")
    self:Refresh()
    return true
end

--- An entry drawn for the spell as it would show (the editor's previews).
local function preview(entry, animate)
    return H:GetSpellIconPreview(E.spell, E.scope, entry, animate == true, who())
end

-- ----- the categories' sources (core/viewer.lua) -----
--
-- Each is a picture viewer source with two more calls: entry(i), the spell's entry for picture i, and mine(entry), the
-- picture an entry names (nil: none of this category's).

--- Basic: the learned effect and the lettered button.
local function basicSource()
    local items = { { kind = "learned" }, { kind = "letter" } }
    return {
        count = function() return #items end,
        picture = function(i)
            if items[i].kind == "letter" then
                -- The book's and the bars' own square for this spell (its placeholder key and letter).
                local _, key, letter = TK.ActionInfo({ kind = "spell", name = E.spell })
                return "icon:" .. (key or "spell"), nil, nil, "The lettered button: the spell's letter, no picture.", 0, letter or "?"
            end
            local key, w, h, frames = preview(items[i], false)
            if key == "" then return "", nil, nil, "The learned effect: not learned yet. Cast the spell once on this server.", 0, "?" end
            return key, w, h, "The learned effect: the animation the server played when you cast it.", frames
        end,
        now = function(i, first, last) return preview({ kind = items[i].kind, first = first, last = last }, true) end,
        entry = function(i) return { kind = items[i].kind } end,
        mine = function(entry)
            if entry and entry.kind == "learned" then return 1 end
            if entry and entry.kind == "letter" then return 2 end
        end,
    }
end

--- One family of the packs' pictures (TK.UI.ArtSource) as a category: an entry of that kind names its picture by the
--- family's id ({ kind = "creature", creature = 12 }).
local function artCategory(family)
    return function()
        local src = W.ArtSource(family)
        src.entry = function(i) return { kind = family, [family] = src.id(i) } end
        src.mine = function(entry) if entry and entry.kind == family then return src.index(entry[family]) end end
        return src
    end
end

local SOURCES_OF = {
    basic = basicSource,
    effects = artCategory("effect"),
    tiles = artCategory("tile"),
    objects = artCategory("object"),
    creatures = artCategory("creature"),
    icons = artCategory("icon"),
}

-- ----- the window -----

local function categoryButton(parent, def, i)
    local b = CreateFrame("Button", "TKSpellIconEditorCategory" .. def.id, parent)
    b:SetSize(LIST_W, 26)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -TOP - (i - 1) * 28)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(0.25, 0.4, 0.8, 0.35)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetColorTexture(1, 1, 1, 0.08)
    b.label = W.Label(b, def.name, 13, W.white, "LEFT")
    b.label:SetPoint("LEFT", b, "LEFT", def.under and 22 or 8, 0) -- a part of the category above, indented
    b:SetScript("OnClick", function() E:ShowCategory(def.id) end)
    return b
end

--- The General page: the icon as it shows now, where it comes from, the global animation option.
local function buildGeneral(parent)
    local g = CreateFrame("Frame", "TKSpellIconEditorGeneral", parent)
    g:SetSize(VIEW_W, VIEW_H)
    g:SetPoint("TOPLEFT", parent, "TOPLEFT", LIST_W + 24, -TOP)
    W.Label(g, "As it shows now", 13, W.gold, "LEFT"):SetPoint("TOPLEFT", g, "TOPLEFT", 4, -4)
    -- The bars' and the book's own drawing (the action icon widget, W.ActionIcon), at the book's size and twice it.
    g.small = CreateFrame("Frame", nil, g)
    g.small:SetSize(36, 36)
    g.small:SetPoint("TOPLEFT", g, "TOPLEFT", 8, -28)
    g.large = CreateFrame("Frame", nil, g)
    g.large:SetSize(72, 72)
    g.large:SetPoint("TOPLEFT", g.small, "TOPRIGHT", 24, 0)
    for _, box in ipairs({ g.small, g.large }) do
        box.icon = select(2, W.SlotArt(box, { edge = false })) -- s6-ui-core (round 62): the shared slot's picture, no edge
        box.glyph = box:CreateFontString(nil, "OVERLAY")
        box.glyph:SetFont(box == g.small and 18 or 36, "OUTLINE")
        box.glyph:SetPoint("CENTER", box, "CENTER", 0, 1)
    end
    g.source = W.Label(g, "", 12, W.white, "LEFT")
    g.source:SetWidth(VIEW_W - 16)
    g.source:SetPoint("TOPLEFT", g.small, "BOTTOMLEFT", 0, -50)
    g.animate = W.Check(g, "Animate spell icons (every spell; the Interface settings' option)", function(on)
        local c = TK.GetComponent("interface")
        if c then
            c:DB().animateSpellIcons = on
            TK.DB:MarkDirty()
        end
        TK.FireEvent("TK_SPELL_ICONS_CHANGED")
        E:Refresh()
    end)
    g.animate:SetPoint("TOPLEFT", g.source, "BOTTOMLEFT", -2, -14)
    local help = W.Label(g, "Choose the picture under Basic, Effects, Tiles (and Objects), Creatures or Icons: a click chooses it for this " ..
        "spell, saved to the scope above. Per Server: every character on this server with this spell. Character: this " ..
        "character only. Global: every server. A character's choice wins over the server's, and the server's over the " ..
        "global one.", 12, { 0.7, 0.7, 0.7 }, "LEFT")
    help:SetWordWrap(true)
    help:SetWidth(VIEW_W - 16)
    help:SetPoint("TOPLEFT", g.animate, "BOTTOMLEFT", 2, -16)
    -- The owner (2026-10-04): "the ability to build a default pack that can come packaged with the server". The global
    -- choices with this server's over them become the server pack (DESIGN.md 4), which the server's packaging ships.
    g.export = W.Button(g, "Export as server pack", 170, 24, nil, function() E:ExportPack() end)
    g.export:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 4, 34)
    local exportNote = W.Label(g, "Every spell's global choice, with this server's over it, as the defaults the server ships " ..
        "(not a character's own).", 11, { 0.7, 0.7, 0.7 }, "LEFT")
    exportNote:SetWordWrap(true)
    exportNote:SetWidth(VIEW_W - 190)
    exportNote:SetPoint("LEFT", g.export, "RIGHT", 10, 0)
    -- While shown, the previews follow the icon's animation (as the bars' and the book's, TK.SpellIconAnimators).
    TK.SpellIconAnimators.spelliconeditor = function()
        if g:IsVisible() then E:DrawGeneral() end
    end
    return g
end

local function build()
    frame = W.Window("TKSpellIconEditor", "Spell Icon", WIDTH, HEIGHT)
    frame.scope = W.Dropdown(frame, "Save to", SCOPES, 150, function(v)
        E.scope = v
        E:Refresh()
    end)
    frame.scope:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -30)
    frame.shown = W.Label(frame, "", 12, { 0.8, 0.8, 0.8 }, "LEFT")
    frame.shown:SetPoint("LEFT", frame.scope, "RIGHT", 16, -8)
    frame.categories = {}
    for i, def in ipairs(CATEGORIES) do frame.categories[def.id] = categoryButton(frame, def, i) end
    frame.general = buildGeneral(frame)
    frame.viewer = W.PictureViewer(frame, VIEW_W, VIEW_H, { name = "TKSpellIconViewer" })
    frame.viewer:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_W + 24, -TOP)
    frame.viewer.onPick = function(i) E:Pick(i) end
    frame.viewer.onRange = function(first, last, frames)
        local entry = E:Entry()
        if not entry then return end
        -- The whole animation is the default: nothing written for it.
        entry.first = first > 0 and first or nil
        entry.last = last < frames - 1 and last or nil
        E:Choose(entry)
    end
    frame.animate = W.Check(frame.viewer.detail.extra, "Always animate this spell", function(on)
        local entry = E:Entry()
        if not entry then return end
        entry.animate = on or nil
        E:Choose(entry)
    end)
    frame.animate:SetPoint("TOPLEFT", frame.viewer.detail.extra, "TOPLEFT", 0, 0)
    -- A creature's facing: south is the default (nothing written); another facing has its own frames, so the range resets.
    frame.viewer.onFacing = function(f)
        local entry = E:Entry()
        if not entry then return end
        entry.facing = f ~= 2 and f or nil
        entry.action = frame.viewer.animation -- an action the new facing does not have gave way to the default (nil)
        entry.first, entry.last, entry.frame = nil, nil, nil
        E:Choose(entry)
    end
    -- Round 3: a creature's action (walk is the default: nothing written); its own frames, so the range resets.
    frame.viewer.onAnimation = function(id, isDefault)
        local entry = E:Entry()
        if not entry then return end
        entry.action = not isDefault and id or nil
        entry.first, entry.last, entry.frame = nil, nil, nil
        E:Choose(entry)
    end
    frame.clear = W.Button(frame, "Clear", 90, 24, nil, function() E:Choose(nil) end)
    frame.clear:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 14)
    frame.clearNote = W.Label(frame, "", 11, { 0.7, 0.7, 0.7 }, "LEFT")
    frame.clearNote:SetPoint("LEFT", frame.clear, "RIGHT", 10, 0)
end

--- Opens the editor on a spell (by its name), saving to Per Server as each opening does, on Icons: the owner's "default to
--- Icons (not learned) then the learned mode" (s6-ui-core round 81, the head's reading of it). The grid marks the
--- scope's own choice, and the detail with its frame controls stays closed until a picture is clicked.
function E:Open(spell)
    if not spell or spell == "" then return end
    if not frame then build() end
    self.spell, self.scope = spell, "server"
    frame.title:SetText("Spell Icon: " .. spell)
    frame:Show()
    TK.FitToScreen(frame)
    self:ShowCategory("icons")
end

function E:Close() if frame then frame:Hide() end end

function E:IsShown() return frame ~= nil and frame:IsShown() end

--- Shows a category: General's page, or a picture source in the viewer.
function E:ShowCategory(id)
    self.category = id
    for cid, b in pairs(frame.categories) do b.bg:SetShown(cid == id) end
    frame.general:SetShown(id == "general")
    frame.viewer:SetShown(SOURCES_OF[id] ~= nil)
    self.source = SOURCES_OF[id] and SOURCES_OF[id]() or nil
    if self.source then frame.viewer:SetSource(self.source, "The packs are needed for these pictures.") end
    self:Refresh()
end

--- "Export as server pack", once confirmed: the pack file written from the global and this server's choices.
function E:ExportPack()
    W.Confirm("Write the server pack from every spell's global choice, with this server's over it? It replaces the pack " ..
        "the server ships.", function()
        local ok, count, path, problem = H:ExportSpellIconPack()
        if ok then
            TK.Notify("Server pack written: " .. count .. " spells, " .. path)
            TK.FireEvent("TK_SPELL_ICONS_CHANGED")
        else
            UIErrorsFrame:AddMessage("The server pack was not written: " .. tostring(problem), 1, 0.3, 0.3)
        end
    end)
end

--- A picture clicked (the viewer has opened its detail): chosen for the spell in the scope, its range, facing and
--- animation reset. The scope's own choice clicked again is kept as it is (its trim, facing and animate), and its
--- controls show it (Astra's review of round 1).
function E:Pick(i)
    local entry = self:Entry()
    if entry and self.source.mine(entry) == i then
        self:Refresh()
        return
    end
    self:Choose(self.source.entry(i))
end

--- The General page's previews, as the bars draw the spell (by its name).
function E:DrawGeneral()
    local g = frame.general
    local action = { kind = "spell", name = self.spell }
    W.ActionIcon(g.small.icon, g.small.glyph, g.small, action, 34, 2)
    W.ActionIcon(g.large.icon, g.large.glyph, g.large, action, 34, 4)
    -- The large one twice the small one's picture (sharp pixel art).
    local w, h = g.small.icon:GetSize()
    if g.small.glyph:GetText() == "" then g.large.icon:SetSize(w * 2, h * 2) end
end

--- Everything again: the scope, what decides the icon now, the category's marks.
function E:Refresh()
    if not frame or not frame:IsShown() then return end
    local entry = self:Entry()
    local source = Icons.Source(self.spell)
    frame.scope:SetValue(self.scope)
    frame.shown:SetText("Shown now: " .. (SOURCES[source] or source))
    local scopeName = self.scope == "server" and "this server" or self.scope == "character" and "this character" or "every server"
    frame.clear:SetEnabled(entry ~= nil)
    frame.clearNote:SetText(entry and ("Clears the choice for " .. scopeName .. ".") or ("Nothing is chosen for " .. scopeName .. "."))
    if self.category == "general" then
        local c = TK.GetComponent("interface")
        frame.general.animate:SetChecked(c ~= nil and c:DB().animateSpellIcons == true)
        frame.general.source:SetText("It comes from " .. (SOURCES[source] or source) .. ".")
        self:DrawGeneral()
        return
    end
    local v = frame.viewer
    if not self.source then return end
    local mine = self.source.mine(entry)
    if v.opened and v.opened ~= mine then v:Close() end
    v:Select(mine)
    if mine and v.opened == mine then
        v:SetFacing(entry.facing or 2) -- before the range: another facing or action has its own frames
        v:SetAnimation(entry.action)
        v:SetRange(entry.first or -1, entry.last or -1)
        frame.animate:SetChecked(entry.animate == true)
    end
    frame.animate:SetShown(v.opened ~= nil and (v.frames or 0) > 1)
end

TK.On("PLAYER_LEAVING_WORLD", function() E:Close() end)
TK.On("TK_SPELL_ICONS_CHANGED", function() if E:IsShown() and frame.viewer:IsShown() then frame.viewer:Refresh() end end)
