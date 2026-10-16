-- s6-rules-dialogs rounds 10-11: D-34, the fitting room (FittingRoomDialog). The preview of the player's figure on the
-- left, its turn buttons (3, 4), "Basic" (5) and "Current" (6); on the right the ten category buttons (7-16) above the
-- item grid (control 2, six by three; each cell's part is its entry's index + 1), which the wheel scrolls here. A release
-- on an item tries it on or takes it off (the model). Close (0: Enter and Esc). Without the item shop's catalogue the
-- grid says so. The preview's look is s6-characters' FittingRoom, kept apart from the selection: the window replays the
-- model's changes into it (its resets, clicks and changes of list, in order) and draws its figure.
--
-- s6-modular-g (interfaces): the window's size, the preview's, the buttons', the grid's and its cells' places and
-- looks are the look's (C.look.Room); this file keeps what the room does.
-- Wire: FittingRoomDialog::OnControlCommand 0x0041C310 by these indexes; a cell's press and release go as control 2 with
-- its entry's index + 1 as the part (the grid's six columns and three rows are 4a's display mode 1, so a page is three
-- rows); changing an index, a part or the grid's columns changes what the server sees. Page Up and Page Down are local.

local C = TK.GetComponent("dialogs")
local H = __tk
local W = TK.UI
local K = C.kit

local Room = { look = "Room" }
local CATEGORIES = { "UsableItems", "Weapons", "Mounts", "Face", "Head", "Mantle", "Necklaces", "Coats", "Shoes", "SpecialtySets" }
local COLS, ROWS = 6, 3

function Room.build()
    local L = C.look.Room
    local win = K.Window(L.width, L.height, "Fitting Room")
    win.preview = L.preview(win)
    win.figure = win.preview.figure
    -- s6-modular-g (round 14, its round 13 finding 2): 4a's turn buttons by index (FittingRoomDialog::GetControlBounds
    -- 0x0041D150): control 3 is "<" on the left (image 44, AdvanceFacingDirection), control 4 ">" on the right (image 45,
    -- RetreatFacingDirection), so "<" turns the figure the way the original's does. Nothing is sent by either.
    win.left = K.Button(win, 3, "<", L.turn)
    win.right = K.Button(win, 4, ">", L.turn)
    win.basic = K.Button(win, 5, "Basic", L.button)
    win.current = K.Button(win, 6, "Current", L.button)
    win.categories = {}
    for i, name in ipairs(CATEGORIES) do
        win.categories[i] = K.Button(win, 6 + i, name, L.category, L.categoryHeight)
    end
    win.grid = CreateFrame("Frame", nil, win)
    win.grid:EnableMouseWheel(true)
    win.grid:SetScript("OnMouseWheel", function(_, delta)
        win.top = math.max(0, math.min(win.lastTop or 0, (win.top or 0) - delta))
        Room.update(win, win.view)
    end)
    win.cells = {}
    for i = 1, COLS * ROWS do
        local cell = L.cell(win.grid, i, COLS)
        -- Control 2, its part the entry shown now (the grid scrolls): the press and its release as K.Wire posts them.
        cell.__dialogWin, cell.__dialogControl, cell.__dialogPart = win, 2, 0
        cell:HookScript("OnMouseDown", function(_, button) K.Pointer(win, 2, button, true, cell.__dialogPart) end)
        cell:HookScript("OnMouseUp", function(_, button)
            local f, over, part = GetMouseFocus(), -1, 0
            if f and f.__dialogWin == win then over, part = f.__dialogControl or -1, f.__dialogPart or 0 end
            K.Pointer(win, over, button, false, part)
        end)
        win.cells[i] = cell
    end
    win.empty = W.Label(win, "", 13, W.white)
    win.close = K.Button(win, 0, "Close", L.button)
    L.place(win, COLS, ROWS)
    -- The preview's figure turns its frame every 300 ms (FittingRoomUserImageControlPane::OnTimer).
    win.preview:SetScript("OnUpdate", function()
        local t = GetTime()
        if win.view and (not win.nextFrame or t >= win.nextFrame) then
            win.nextFrame = t + 0.3
            Room.figure(win, win.view)
        end
    end)
    return win
end

-- s6-rules-dialogs / s6-characters: the fitting room's look and figure are s6-characters' host calls (its round 23,
-- on main: OpenFittingRoom, ClickFittingRoomItem, SetFittingRoomCategory, GetFittingRoomFigure).

--- The model's preview changes not yet given to the figure side, in order; all of them again after a reset.
function Room.sync(win, c)
    local ops = c.preview or {}
    if win.generation ~= c.previewGeneration or win.syncedSerial ~= win.serial or (win.applied or 0) > #ops then
        win.generation, win.syncedSerial, win.applied = c.previewGeneration, win.serial, 0
    end
    for i = (win.applied or 0) + 1, #ops do
        local op = ops[i]
        if op[1] == "reset" then
            H:OpenFittingRoom(op[2] and true or false)
        elseif op[1] == "click" then
            local parts = {}
            for j, p in ipairs(op[4] or {}) do parts[j] = { part = p[1], tile = p[2], color = p[3] } end
            H:ClickFittingRoomItem(op[2], op[3], parts)
        elseif op[1] == "category" then
            H:SetFittingRoomCategory(op[2])
        end
    end
    win.applied = #ops
end

function Room.figure(win, view)
    local c = view.contents
    local key, w, h = H:GetFittingRoomFigure(c.direction or 2, -1)
    if key and key ~= "" then
        win.figure:SetTexture(key)
        win.figure:SetSize(w or C.look.Room.previewSize, h or C.look.Room.previewSize)
        win.figure:Show()
    else
        win.figure:Hide()
    end
end

function Room.update(win, view)
    local c = view.contents
    if win.opened then win.top, win.category = 0, c.category end
    if c.category ~= win.category then win.top, win.category = 0, c.category end
    for i, b in ipairs(win.categories) do
        b:SetShown(c.catalog and true or false)
        b.mark:SetShown(c.selectedButton == 6 + i)
    end
    local entries = c.entries or {}
    local rows = math.ceil(#entries / COLS)
    win.lastTop = math.max(0, rows - ROWS)
    win.top = math.min(win.top or 0, win.lastTop)
    for i, cell in ipairs(win.cells) do
        local index = (win.top or 0) * COLS + i
        local e = entries[index]
        cell:SetShown(e ~= nil)
        if e then
            cell.__dialogPart = index
            -- s6-interface-7x (round 2): with its colour (e[3], the catalogue's dye), as 4a's grid draws it
            -- (FittingRoomScrollPane.cpp:819); undyed, the icon as before
            local key, w, h = TK.Art.Item(e[2] or 0, e[3])
            if key then
                -- s6-modular-g (interfaces, round 13): a look may place the picture its own way (7.x's: 4a's half size above
                -- 50 pixels); drawing only
                if C.look.Room.placeIcon then C.look.Room.placeIcon(cell, key, w, h)
                else TK.Art.Place(cell.icon, cell, key, w, h, C.look.Room.icon) end
                cell.icon:Show()
            else
                cell.icon:Hide()
            end
            cell.name:SetText(e[1] or "")
            cell.on:SetShown(e[4] and true or false)
        end
    end
    win.empty:SetText(c.catalog and "" or "The item shop's catalogue is not on this computer.")
    Room.sync(win, c)
    Room.figure(win, view)
end

--- Round 19: Page Up and Page Down scroll the grid a page (its three rows), within the first and the last page, while
--- the grid has the focus and no modifier is held (FittingRoomListPane::HandleKeyOrTextEvent, FittingRoomScrollPane.cpp:
--- 873-905, display mode 1). Off the wire.
function Room.key(win, key)
    if (key ~= "PAGEUP" and key ~= "PAGEDOWN") or not win.view or win.view.focus ~= 2 then return end
    win.top = math.max(0, math.min(win.lastTop or 0, (win.top or 0) + (key == "PAGEUP" and -ROWS or ROWS)))
    Room.update(win, win.view)
end

C.renderers.FittingRoomDialog = Room
