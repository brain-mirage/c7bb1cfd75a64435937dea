-- The macro window's name and icon popup (New, Change Name/Icon), as WoW's behaves (round 8; WoW's window read for its
-- behaviour only, docs/research/wow-macro-behaviour.md section 9): a name of 16 characters at most, and an icon from a
-- scrolling grid: the question mark first (a macro with it shows what it would use), the vendored Twemoji set, the icons
-- of the spells the player knows, then the game's item icons from the packs. OK needs a name. While it is open the
-- window's tabs, New, Delete, Change Name/Icon, Save and the text box wait (for New the text box is hidden, as WoW's:
-- review r8, 1); picking a macro in the pool closes it. It stays on the screen beside the window (review r8, 2).

local C = TK.GetComponent("macros")
local H = __tk
local W = TK.UI

local COLS, ROWS, CELL = 7, 6, 38

--- The grid's last top row: the one that shows the last icons (0 when they all fit).
local function lastTop(p) return math.max(0, math.ceil(#p.icons / COLS) - ROWS) end

--- A macro's icon (a Twemoji code, or an "art:" key of the packs) as a picture: the art's key and size, or the Twemoji's
--- "emoji:" key at 72 x 72, the question mark for none or for art the packs do not have (the window and the buttons:
--- TK.MacroActionInfo).
function C.IconArt(icon)
    if icon and icon:sub(1, 4) == "art:" then
        local ok, w, h = H:GetArtSize(icon)
        if ok then return icon, w, h end
        icon = nil
    end
    return "emoji:" .. ((icon and icon ~= "") and icon or C.ICONS[1]), 72, 72
end

--- Shows a macro's icon in a texture, centred on anchor in a box.
function C.ShowIcon(tex, icon, anchor, box)
    local key, w, h = C.IconArt(icon)
    if key:sub(1, 4) == "art:" then
        TK.Art.Place(tex, anchor, key, w, h, box)
        return
    end
    tex:SetTexture(key)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:ClearAllPoints()
    tex:SetSize(box, box)
    tex:SetPoint("CENTER", anchor, "CENTER", 0, 0)
end

--- Every icon the chooser offers, in its order, as a macro keeps them ("2753", "art:icon/12", a spell's "art:" key).
function C.IconChoices()
    local list, seen = {}, {}
    local function add(icon)
        if icon and icon ~= "" and not seen[icon] then
            seen[icon] = true
            list[#list + 1] = icon
        end
    end
    for _, code in ipairs(C.ICONS) do add(code) end
    for slot = 1, 52 do
        local name, _, _, _, art = TK.ActionInfo({ kind = "spell", slot = slot })
        if name and type(art) == "string" and art:sub(1, 4) == "art:" then add(art) end
    end
    for n = 0, H:MacroIconCount() - 1 do add("art:icon/" .. n) end
    return list
end

-- Gives an edit box the keyboard now, and again a frame later, after the click that asked for it is done.
local focusLater = CreateFrame("Frame", nil, UIParent)
function C.FocusSoon(box)
    box:SetFocus()
    focusLater:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        if box:IsShown() then box:SetFocus() end
    end)
end

local function build(window)
    local p = W.Panel(window, "TKMacroPopup")
    W.HudPanel(p) -- s6-ui-core (round 53): beside the window, a window of its own at the UI transparency
    p:SetSize(COLS * CELL + 56, ROWS * CELL + 172)
    p:EnableMouse(true)
    -- Beside the window on the screen, also while the window is dragged with it open (review r8, 2).
    p:SetScript("OnUpdate", function() C:PlacePopup() end)
    p.title = W.Label(p, "", 14, W.gold)
    p.title:SetPoint("TOP", p, "TOP", 0, -12)
    local nameLabel = W.Label(p, "Name (16 characters at most):", 11, W.white, "LEFT")
    nameLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 18, -38)
    p.name = W.EditBox(p, COLS * CELL, 22)
    p.name:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    p.name:SetMaxLetters(C.MAX_NAME)
    p.name:SetScript("OnTextChanged", function() C:PopupState() end)
    p.name:SetScript("OnEnterPressed", function() C:PopupOkay() end)
    local iconLabel = W.Label(p, "Choose an icon:", 11, W.white, "LEFT")
    iconLabel:SetPoint("TOPLEFT", p.name, "BOTTOMLEFT", 0, -10)
    p.grid = CreateFrame("Frame", "TKMacroIconGrid", p)
    p.grid:SetSize(COLS * CELL, ROWS * CELL)
    p.grid:SetPoint("TOPLEFT", iconLabel, "BOTTOMLEFT", 0, -4)
    p.grid:EnableMouseWheel(true)
    p.grid:SetScript("OnMouseWheel", function(_, delta) C:IconScroll(delta > 0 and -1 or 1) end)
    p.cells = {}
    for i = 1, COLS * ROWS do
        local b = CreateFrame("Button", "TKMacroIconChoice" .. i, p.grid)
        b:SetSize(CELL - 2, CELL - 2)
        b:SetPoint("TOPLEFT", p.grid, "TOPLEFT", (i - 1) % COLS * CELL, -math.floor((i - 1) / COLS) * CELL)
        -- s6-ui-core (round 62): the shared slot's picture, its edge the chosen mark (gold), no light
        local _
        _, b.tex, b.sel = W.SlotArt(b, { edge = W.gold, light = false })
        b:SetScript("OnClick", function(self)
            if not self.icon then return end
            p.icon = self.icon
            C:IconPage()
            C:PopupState()
        end)
        p.cells[i] = b
    end
    p.up = W.Button(p, "^", 26, 22, nil, function() C:IconScroll(-ROWS) end)
    p.up:SetPoint("TOPLEFT", p.grid, "TOPRIGHT", 4, 0)
    p.down = W.Button(p, "v", 26, 22, nil, function() C:IconScroll(ROWS) end)
    p.down:SetPoint("BOTTOMLEFT", p.grid, "BOTTOMRIGHT", 4, 0)
    p.where = W.Label(p, "", 10, W.grey, "LEFT")
    p.where:SetPoint("TOPLEFT", p.grid, "BOTTOMLEFT", 0, -4)
    p.ok = W.Button(p, "OK", 80, 24, nil, function() C:PopupOkay() end)
    p.ok:SetPoint("BOTTOMRIGHT", p, "BOTTOM", -4, 14)
    p.cancel = W.Button(p, "Cancel", 80, 24, nil, function() C:PopupCancel() end)
    p.cancel:SetPoint("BOTTOMLEFT", p, "BOTTOM", 4, 14)
    p:Hide()
    window.popup = p
    return p
end

--- Puts the popup beside the window: on its right when it fits on the screen there, else on its left; where neither
--- side fits, on the side with more room.
function C:PlacePopup()
    local window = self.window
    local p = window.popup
    local l, _, w = window:GetRect()
    if not l then return end
    local screen, width = UIParent:GetWidth(), p:GetWidth()
    local roomRight, roomLeft = screen - (l + w) - 4, l - 4
    local side = (roomRight >= width or (roomLeft < width and roomRight >= roomLeft)) and "right" or "left"
    if p.side == side then return end
    p.side = side
    p:ClearAllPoints()
    if side == "right" then p:SetPoint("TOPLEFT", window, "TOPRIGHT", 4, 0)
    else p:SetPoint("TOPRIGHT", window, "TOPLEFT", -4, 0) end
end

--- Opens the popup: "new" (no name yet, the question mark chosen, as WoW's) or "edit" (the selected macro's name and icon).
function C:OpenPopup(mode, name, icon)
    local window = self.window
    local p = window.popup or build(window)
    p.mode = mode
    p.title:SetText(mode == "new" and "New Macro" or "Change Name and Icon")
    p.icons = C.IconChoices()
    p.icon = icon or C.ICONS[1]
    p.top = 0
    for i, v in ipairs(p.icons) do
        if v == p.icon then
            p.top = math.floor((i - 1) / COLS)
            break
        end
    end
    p.top = math.min(p.top, lastTop(p))
    p.name:SetText(name or "")
    window.body:ClearFocus()
    self:PlacePopup()
    p:Show()
    C.FocusSoon(p.name)
    self:IconPage()
    self:PopupState()
    self:WindowState()
end

function C:PopupOpen() return self.window ~= nil and self.window.popup ~= nil and self.window.popup:IsShown() end

--- The grid's rows from the top row shown.
function C:IconPage()
    local p = self.window.popup
    for i, b in ipairs(p.cells) do
        local icon = p.icons[p.top * COLS + i]
        b.icon = icon
        b:SetShown(icon ~= nil)
        if icon then
            C.ShowIcon(b.tex, icon, b, CELL - 8)
            b.sel:SetShown(icon == p.icon)
        end
    end
    p.where:SetText(string.format("Icons %d-%d of %d", p.top * COLS + 1, math.min(#p.icons, (p.top + ROWS) * COLS), #p.icons))
    p.up:SetEnabled(p.top > 0)
    p.down:SetEnabled(p.top < lastTop(p))
end

function C:IconScroll(rows)
    local p = self.window.popup
    p.top = math.max(0, math.min(lastTop(p), p.top + rows))
    self:IconPage()
end

function C:PopupState()
    local p = self.window.popup
    if not p then return end
    p.ok:SetEnabled((p.name:GetText() or ""):match("%S") ~= nil and p.icon ~= nil)
end

--- OK: a new macro in the tab's set, selected, its text box ready; or the selected macro's new name and icon.
function C:PopupOkay()
    local p = self.window.popup
    local name = (p.name:GetText() or ""):match("^%s*(.-)%s*$")
    if name == "" or not p.icon then return end
    if p.mode == "new" then
        if not self:CreateMacro(name, p.icon) then return end
    else
        self:Rename(name, p.icon)
    end
    self:ClosePopup()
    if p.mode == "new" then C.FocusSoon(self.window.body) end
end

function C:PopupCancel() self:ClosePopup() end

function C:ClosePopup()
    local p = self.window and self.window.popup
    if p and p:IsShown() then
        p.name:ClearFocus()
        p:Hide()
    end
    if self.window then self:WindowState() end
end
