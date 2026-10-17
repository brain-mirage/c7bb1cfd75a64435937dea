-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md; docs/development/interfaces.md,
-- "The dialogs: geometry is the look's, behaviour is shared"): 5.x's look of the dialogs, 5.33's own windows. A
-- renderer (components/dialogs/) makes its window's parts with their control indexes, fills them from the dialog model
-- and passes the player's input on; a look only sizes, places and draws them: nothing in it reaches the model or the
-- server.
--
-- Drawn so far: 5.33's common dialog frame, the alerts (AlertPane 0x00421BA0 and the classes built on it). Its numbers
-- are 7.5.2's to the pixel (the message's width clamped to 160-240 with two buttons, 74-240 with one, + 48; its lines +
-- 80; the 74 x 20 text buttons at (W - 184, H - 44) and (W - 98, H - 44); TextButtonControlPane::OnPaint 0x00418C40's
-- face and bevels; DialogPane's Enter frame in 0x84), so the original client's alerts draw it
-- (interfaces/original/alerts.lua) with what is 5.33's own here: the standard window (DLGFRAME.EPF in NPAL8.PAL,
-- 16-pixel tiles: DialogPane::DrawBackground 0x00420FC0 and DrawBorder 0x00421050), the 640 x 480 screen and its
-- centre. Round 2: the NPC dialogs, 5.33's own windows by its own numbers (dialogs/npc.lua) with its pictures and image
-- buttons (X.Image below). s6-interface-5x-b: the user list and the friend list (dialogs/social.lua).
-- Every other dialog keeps the shared default look (window included) until it has its 5.x entry: an entry of this table
-- is 5.x's; the dialogs component resolves the others over the default look (the separation's step 6 and Q2;
-- s6-interface-5x round 15, step 9: they were Modern's look's before).
--
-- s6-interface-5x-b (round 9, the interface separation's step 5: docs/development/interface-separation.md, section 6):
-- the helpers are the original client's kit (interfaces/original/dialogkit.lua), made with 5.x's skin (5.33's font 0
-- and its measures), its 640 x 480 screen and L.Place; they were 7.x's look's before. What is 5.33's own (its frames,
-- image buttons, radios, portrait, item rows, default button, no slide) overrides them below.

local fallback = TK.Dialogs.DefaultLook()
local S = require("interfaces.5x.skin")
local Screen = require("interfaces.screen")

local L = {} -- the entries 5.x has not are resolved by the dialogs component, over its default look
-- Wire policy consumed by shared K.Edit: 4a Activate 0x00498ED0 selects all, then OnMouseEvent 0x00590DE0 places
-- the native caret in the same pointer event. Changing this changes the text a later command sends to the server.
L.NativePointerCaret = true
local X = require("interfaces.original.dialogkit")({
    skin = S,
    screen = { width = S.WIDTH, height = S.HEIGHT },
    place = function(win) L.Place(win) end,
})
-- the look that draws the windows 5.x leaves (the kit's alerts ask it; the hired merchant's quantity, merchant.lua)
X.Fallback = fallback

X.DIALOG_FRAME = { file = "DLGFRAME.EPF", palette = "NPAL8.PAL", tile = 16 }

--- The standard window's frames (DLGFRAME.EPF's): the background 8, the edges 1 top, 6 bottom, 3 left, 4 right, the corners
--- 0, 2, 5, 7, the background over all of it (inset 0).
local FRAME_TILES = { bg = 8, top = 1, bottom = 6, left = 3, right = 4, tl = 0, tr = 2, bl = 5, br = 7, inset = 0 }

-- the kit's standard window (7.5.2's), drawn where the 5.33 set is not
local kitFrame = X.Frame

--- 5.33's standard window at w x h from a frame picture of the 5.33 set: its background frame tiled from the window's top
--- left over all of it (DialogPane::DrawBackground), then its border tiles of size pixels (DrawBorder: the top and bottom
--- edges from one tile in while a tile ends before the last, the left and right alike, then the corners). tiles: which
--- frame is which, and the background's inset (FRAME_TILES by default; s6-interface-5x-b, round 6: the paper's,
--- LINE001.EPF, numbers them otherwise and tiles its background inside 16 pixels). Its textures are the window's
--- (win.frameTiles), kept for its next size.
function X.Frame(win, w, h, file, palette, size, tiles)
    tiles = tiles or FRAME_TILES
    -- without the 5.33 set (not built where the packs are) 7.5.2's standard window, so the dialog stays readable
    if not S.Image(file, tiles.bg, palette) then return kitFrame(win, w, h, "DLGFRAME.EPF", "PAL01.PAL", 14) end
    win.frameTiles = win.frameTiles or {}
    for _, t in ipairs(win.frameTiles) do t:Hide() end
    local n = 0
    local function tile(index, x, y, right, bottom)
        n = n + 1
        local t = win.frameTiles[n]
        if not t then
            t = win:CreateTexture(nil, "BACKGROUND")
            win.frameTiles[n] = t
        end
        local key, tw, th = S.Image(file, index, palette)
        if not key then return end
        local ox, oy = TK.Art.Origin(key)
        local cw, ch = math.max(0, math.min(tw, (right or w) - x - ox)), math.max(0, math.min(th, (bottom or h) - y - oy))
        if cw == 0 or ch == 0 then return end
        t:SetTexture(key)
        t:SetTexCoord(0, cw / tw, 0, ch / th)
        t:SetSize(cw, ch)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", win, "TOPLEFT", x + ox, -(y + oy))
        t:Show()
    end
    local i = tiles.inset or 0
    for y = i, h - i - 1, size do
        for x = i, w - i - 1, size do tile(tiles.bg, x, y, w - i, h - i) end
    end
    local x = size
    repeat tile(tiles.top, x, 0) tile(tiles.bottom, x, h - size) x = x + size until x >= w - size
    local y = size
    repeat tile(tiles.left, 0, y) tile(tiles.right, w - size, y) y = y + size until y >= h - size
    tile(tiles.tl, 0, 0) tile(tiles.tr, w - size, 0) tile(tiles.bl, 0, h - size) tile(tiles.br, w - size, h - size)
end

-- ----- 5.33's controls (round 2: the NPC dialogs) -----

--- An image button of 5.33's (ImageButtonControlPane_OnPaint 0x00419760): the kit's button (its control index, its
--- input and its sound unchanged) drawn with BUTT001.EPF's frames 2 x id (normal) and 2 x id + 1 (pressed), or for ids
--- 51-57 BUTT002.EPF's 2 x (id - 50) and + 1, in NPAL8.PAL, at its rectangle's top left; disabled, the normal picture
--- under a 0x8F wash (draw mode 2); with the focus, a 1-pixel frame in 0x80 round its rectangle (L.FocusEdge). No
--- caption and no hover: the pictures carry the captions.
function X.Image(win, btn, id, l, t, r, b)
    btn.noClickSound = true -- s6-interface-5x-b (round 6): no click sound, as 4a's and 5.33's controls (the kit's X.Image)
    X.Rect(btn, win, l, t, r, b)
    local w, h = r - l, b - t
    if btn.x5id == id and btn.x5size == w * 10000 + h then return end -- drawn already (a window used again)
    btn.x5id, btn.x5size = id, w * 10000 + h
    -- the pictures it had for its states (the kit's, or another id's) give way
    for _, old in ipairs({ btn.__normal, btn.__pushed, btn.__disabled }) do if old then old:Hide() end end
    local file, base = "BUTT001.EPF", 2 * id
    if id >= 51 then file, base = "BUTT002.EPF", 2 * (id - 50) end
    btn:SetNormalTexture(S.Picture(btn, nil, file, base, "NPAL8.PAL", 0, 0, "ARTWORK"))
    btn:SetPushedTexture(S.Picture(btn, nil, file, base + 1, "NPAL8.PAL", 0, 0, "ARTWORK"))
    btn:SetDisabledTexture(S.Picture(btn, nil, file, base, "NPAL8.PAL", 0, 0, "ARTWORK"))
    -- the wash over the disabled picture, shown with the button's state (the kit sets it by SetEnabled)
    if not btn.x5wash then
        btn.x5wash = S.Fill(btn:CreateTexture(nil, "OVERLAY"), S.WHITE, 0.5)
        btn.x5wash:SetAllPoints(btn)
        local setEnabled = btn.SetEnabled
        function btn:SetEnabled(on)
            setEnabled(self, on)
            self.x5wash:SetShown(not on)
            -- the Enter frames round the default button follow its state (0x84, 0x86 disabled: X.Default)
            if win.x5default == self then X.EnterFrame(win, win.x5enter and self or nil) end
        end
        -- the default button's own frame in colour 1 (X.Default), under the focus's frame
        btn.x5sel = {}
        for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
                             { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
            local e = S.Fill(btn:CreateTexture(nil, "OVERLAY", nil, 1), S.BLUE)
            e:SetPoint(p[1], btn, p[1], 0, 0)
            e:SetPoint(p[2], btn, p[2], 0, 0)
            if p[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
            e:SetShown(win.x5default == btn)
            btn.x5sel[i] = e
        end
        win.x5buttons = win.x5buttons or {}
        table.insert(win.x5buttons, btn)
    end
    btn.x5wash:SetShown(not btn:IsEnabled())
    if not btn.x5edge then
        btn.x5edge = {}
        for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
                             { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
            local e = S.Fill(btn:CreateTexture(nil, "OVERLAY", nil, 2), S.TEXT)
            e:SetPoint(p[1], btn, p[1], 0, 0)
            e:SetPoint(p[2], btn, p[2], 0, 0)
            if p[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
            e:SetShown(btn.x5focus == true) -- the focus the kit marked before the button had its pictures
            btn.x5edge[i] = e
        end
    end
    if btn.GetHighlightTexture and btn:GetHighlightTexture() then btn:GetHighlightTexture():SetColorTexture(0, 0, 0, 0) end
    local label = btn:GetFontString()
    if label then label:Hide() end
end

--- A radio option of 5.33's (RadioGroupControlPane's paint, sub_419DA0): RADIOBUT.EPF in NPAL8.PAL, frame 1 chosen and 0
--- not (enabled), at the option rectangle's left, its top on the rectangle's middle - 5 (S.Picture, the texture kept under
--- key of win). s6-interface-5x-b: the user list's sort (social.lua), the music dialog's radios (misc.lua).
function X.Radio(win, key, chosen, l, t, b)
    win[key] = S.Picture(win, win[key], "RADIOBUT.EPF", chosen and 1 or 0, "NPAL8.PAL", l, math.floor((t + b) / 2) - 5)
end

--- The portrait (ObjectImageControlPane) at (l, t)-(r, b): the object centred, on nothing (pane mode 1), the base set's
--- picture at S.GAME_ART (s6-interface-5x-b, round 6: 5.33's art, half 7.5.2's, in 5.33's rectangle).
function X.Portrait(win, l, t, r, b)
    win.portraitSpec = { width = r - l, height = b - t, left = l, top = -t, textX = 0, black = false, scale = S.GAME_ART }
end

-- ----- 5.33's list rows (round 4: the merchants, the trade, the boards) -----

--- An item row of 5.33's lists: the item's picture (it.item, the server's 0xC000-biased picture number, or it.icon, an
--- icon number of ITEM.EPF; with its colour, it.colour, dyed as 7.x's: TK.Art.Item) at its full size, centred on x cx and
--- on the row's middle by its whole frame (GetItemGlyphBounds 0x00449230) and not clipped to the row
--- (ItemObjImageLib_DrawItemImage 0x00449010, with the row's colour byte: the merchants' 0x004713B0 and 0x004708F0, the
--- trade's 0x0042C970, the pickers' 0x0042CFE0; 7.5.2's halve and clip it), and its name from x, fitted to width with
--- "..." (nil: the whole name, as the trade's rows). Base-set pictures, at S.GAME_ART (s6-interface-5x-b, round 6: 5.33's
--- full size is half 7.5.2's).
function X.ItemRow(list, row, it, cx, x, width)
    if not row.itemIcon then row.itemIcon = row:CreateTexture(nil, "ARTWORK") end
    local picture = it.item or (it.icon and it.icon >= 0 and (it.icon + 0xC000) % 0x10000) or nil
    local key, w, h
    if picture then key, w, h = TK.Art.Item(picture, it.colour) end
    local ok, fw, fh
    if key then
        ok, fw, fh = __tk:GetArtFrameSize(key)
        if not ok then ok, fw, fh = true, w, h end -- a dyed picture: drawn at its frame rectangle's size
    end
    if key and ok then
        local k = S.GAME_ART
        local ox, oy = TK.Art.Origin(key)
        fw, fh = math.floor(fw * k), math.floor(fh * k)
        local left, top = cx - math.floor(fw / 2), math.floor(list.rowHeight / 2) - math.floor(fh / 2)
        row.itemIcon:SetTexture(key)
        row.itemIcon:SetTexCoord(0, 1, 0, 1)
        row.itemIcon:SetSize(w * k, h * k)
        row.itemIcon:ClearAllPoints()
        row.itemIcon:SetPoint("TOPLEFT", row, "TOPLEFT", left + math.floor(ox * k), -(top + math.floor(oy * k)))
        row.itemIcon:Show()
    else
        row.itemIcon:Hide()
    end
    row.text:Hide()
    local name = it.name or ""
    X.RowText(row, "itemName", x):SetText(width and X.Fit(name, width) or name)
end

--- A list's rows' colours, as every 5.33 row painter draws them: the selected row on a 0x25 bar its whole cell wide with
--- its own texts in 0x80, the others' in 0x25 (bar: false for the trade's rows, which have none). The kit's list paints
--- a row with it (list.rowPainter).
function X.RowColours(list, bar)
    list.rowPainter = function(row, selected)
        if bar == false then row.sel:Hide() end
        local c = (selected and bar ~= false) and S.TEXT or S.LIST
        for _, key in ipairs({ "itemName", "x7price", "x7count" }) do
            if row[key] then row[key]:SetTextColor(S.Colour(c)) end
        end
    end
end

--- The dialog's default button (DialogPane__SetFocusedControl 0x0041FC10): DialogPane's Enter frames round it
--- (X.EnterFrame, the kit's) and its own 1-pixel frame in colour 1 (ButtonControlPane +240, drawn by
--- ImageButtonControlPane_OnPaint 0x00419760 under the focus's 0x80 frame); none for a dialog without one (btn nil)
--- or whose paint draws none (frames false: TextMenuDialog__OnPaint 0x0046EDA0; the profile, which the real 5.33 draws
--- without them, misc.lua). Drawing only.
function X.Default(win, btn, frames)
    win.x5enter = frames ~= false
    X.EnterFrame(win, win.x5enter and btn or nil)
    win.x5default = btn
    for _, b in ipairs(win.x5buttons or {}) do
        for _, e in ipairs(b.x5sel or {}) do e:SetShown(b == btn) end
    end
end

-- 5.33 slides its dialogs open as 7.5.2 does (DialogPane::SlideOpenVertical 0x004208F0, 5.33's dump
-- dialogbase2.c:28-68: five steps 24 ms apart, step i drawn (4-i)*h/5 higher, as 7.5.2's 0x0049EAC0), so this look
-- keeps the kit's slide (X.SlideOpen, X.Sliding) and slides the windows 7.x slides (L.Open, and the fits that know their
-- size). The picture only: the stall is the dialog model's in every look (Dialog.Slide), so what is sent and when is
-- unchanged by it. (The owner, 2026-10-12: a real-client difference is fixed in both forms; the XML twin's the same.)

-- ----- what every 5.x dialog shares -----

--- A dialog's window for a 5.x entry, 5.33's (its picture, its controls): the kit's (X.Window; the title is kept but
--- not drawn, as DialogPane stores it and never draws it), marked as 5.x's (win.x5). The component supplies the entry,
--- and draws a dialog 5.x leaves (no entry, or a class in entry.default) with the default look. A window built outside a
--- dialog's build has no entry and is the default look's too.
function L.Window(width, height, title, entry)
    if not entry then return fallback.Window(width, height, title) end
    local f = X.Window(width, height, title, entry)
    f.x5 = true
    return f
end

--- Where a 5.x dialog opens, on the 5.x screen and at its scale: centred on its entry's centre (the alerts': the
--- screen's, AlertPane), else the screen's. That is 5.33's placement slot for the dialogs drawn so far: the NPC and
--- merchant dialogs open at slot 1 (DialogPane__DialogPane's slot argument), and 5.33's defaults centre slots 0-11 and
--- 13-15 on (320, 240) (RegistryConfig_InitializeDefaults 0x00413990; DialogPane_RestoreSavedPosition 0x00421410 puts
--- a dialog's centre there, mode 1); slot 12 alone is placed by its top right at (432, 11). Its place on the screen is
--- kept (win.screenX, win.screenY), as the kit asks of a look's placing. Drawing only.
function L.Place(win)
    local s, left, top = Screen.Fit(S.WIDTH, S.HEIGHT)
    win:SetScale(s)
    local w, h = math.floor(win:GetWidth() + 0.5), math.floor(win:GetHeight() + 0.5)
    local cx, cy = X.CENTRE[1], X.CENTRE[2]
    if win.lookEntry.centre then cx, cy = win.lookEntry.centre(win) end
    local x, y = cx - math.floor(w / 2), cy - math.floor(h / 2)
    win.screenX, win.screenY = x, y
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (left + x * s) / s, -(top + y * s) / s)
end

--- Whether a window is sliding open now (the tests wait for its place: DialogPlayBase.SlidesDone): the kit's (X.Sliding).
function L.Sliding() return X.Sliding() end

--- A 5.x window opening: at its place, with the open sound (DialogPane::AddToLayer 0x0041FCA0 plays sample 408, 0x198,
--- at volume 100, as 7.5.2's: TK.Game.Sound.PlayEffect); an entry of a fixed size that slides open (entry.slide, as
--- 7.x's: true, or a test of the window and its view) slides now, the others when their size is known (their fit).
--- Drawing and sound only.
function L.Open(win, view, i, layout)
    if not win.x5 then return fallback.Open(win, view, i, layout) end
    L.Place(win)
    -- (not the quit's line, round 7: a LineInputPane is no dialog)
    if win.className ~= "QuitDialog" then TK.Game.Sound.PlayEffect(0x198) end
    local slide = win.lookEntry.slide
    if type(slide) == "function" then slide = slide(win, view) end
    if slide then X.SlideOpen(win) end
end

--- The focus's mark on 5.x's windows (win: the frame's window, which the kit passes): an image button's 1-pixel frame in
--- 0x80 (X.Image); none on the text buttons, lists and edits (theirs draw none). The default look's edge on its windows.
function L.FocusEdge(frame, win)
    if not (win and win.x5) then return fallback.FocusEdge(frame) end
    local mark = {}
    function mark:SetShown(on)
        frame.x5focus = on
        for _, e in ipairs(frame.x5edge or {}) do e:SetShown(on) end
    end
    return mark
end

-- The families drawn so far: the alerts, by the original client's (interfaces/original/alerts.lua) with this look's X;
-- the NPC dialogs (round 2), the merchants, the trade and the boards and mail (round 4), by 5.33's numbers. Where the
-- 5.33 set is not, they keep the default look's windows, readable.
require("interfaces.original.alerts")(L, X)

-- s6-interface-5x-b (round 7, s6-interface-5x's Y3): the quit as 5.33 asks it. 5.33 has no quit window: QuitInputPane
-- (constructor 0x004DA830), a LineInputPane, asks on the input line where every prompt is drawn ((14, 456)-(422, 468),
-- 5.x's chat line: panels/chat), its question (string 3, the same in 7.5.2's table: "Do you really want to leave? (Y/N)")
-- black on white with the caret after it. The dialog stays 7.5.2's QuitDialog (the rules': Y quits with 0B, N closes,
-- Enter and Esc its Yes and No), as 5.x keeps 7.5.2's input rules; the line draws no buttons. Drawing only.
local QUIT_LINE = { 14, 456, 408, 12 }
local alertCentre, alertButtons = L.Alert.centre, L.Alert.buttons
L.Alert.centre = function(win)
    if win.className ~= "QuitDialog" then return alertCentre(win) end
    return QUIT_LINE[1] + QUIT_LINE[3] / 2, QUIT_LINE[2] + QUIT_LINE[4] / 2, false
end
L.Alert.buttons = function(win, two)
    if not (win.lookEntry and win.className == "QuitDialog") then return alertButtons(win, two) end
    X.Size(win, QUIT_LINE[3], QUIT_LINE[4])
    if not win.x5line then
        win.x5line = S.Fill(win:CreateTexture(nil, "BACKGROUND"), S.WHITE)
        win.x5line:SetAllPoints(win)
    end
    local text = win.text
    S.Text(text, S.TEXT)
    text:SetWordWrap(false)
    text:SetJustifyH("LEFT")
    text:SetWidth(QUIT_LINE[3])
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -1)
    text:SetText(TK.Util.WithCaret(text:GetText(), #text:GetText()))
    win.b1:Hide()
    win.b2:Hide()
    X.EnterFrame(win, nil)
end

if S.Image("DLGMSG1.EPF", 0, "NPAL8.PAL") then
    for _, family in ipairs({ "npc", "merchant", "exchange", "boards" }) do
        require("interfaces.5x.dialogs." .. family)(L, X)
    end
end
-- s6-interface-5x-b: the user list and the friend list (dialogs/social.lua), likewise only with the 5.33 set; round 6:
-- the profile, the paper and the music dialog (misc.lua), the timer (panes.lua), the Power window (shops.lua), the barber
-- (heads.lua); round 8: the browser (web.lua)
if S.Image("USERLIST.EPF", 0, "NPAL8.PAL") then
    for _, family in ipairs({ "social", "misc", "panes", "shops", "heads", "web" }) do
        require("interfaces.5x.dialogs." .. family)(L, X)
    end
    -- s6-interface-5x-b (round 6): with them, this look is drawn from the old art, so the rules open 4a's legacy branch of
    -- a dialog that has one (components/dialogs/main.lua, C:ApplySettings: the profile's CANCEL, which L.Profile draws)
    L.LegacyLayouts = true
end

require("interfaces.5x.dialogs.worldmap")(L)

-- 5.x's drawing helpers, for its panels (the map name's fitting)
L.X = X

return L
