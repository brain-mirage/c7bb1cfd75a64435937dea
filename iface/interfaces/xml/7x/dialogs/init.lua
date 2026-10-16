-- s6-modular-g (interfaces, phase 4; docs/development/interfaces.md, "The dialogs: geometry is the look's,
-- behaviour is shared"): 7.x's look of the dialogs, 4a's own windows from Source-5's class pages. A renderer
-- (components/dialogs/) makes its window's parts with their control indexes, fills them from the dialog model and passes
-- the player's input on; this look only sizes, places and draws them: nothing in it reaches the model or the server.
--
-- The dialogs drawn so far are the families' files here (npc.lua, merchant.lua, exchange.lua, panes.lua, boards.lua,
-- social.lua, web.lua, album.lua, shops.lua, fitting.lua, options.lua, macros.lua, misc.lua, heads.lua, generic.lua)
-- and the original client's alerts (interfaces/original/alerts.lua, drawn with X); every other dialog keeps the shared
-- default look (window included) until it has its 7.x entry: an entry of this table is 7.x's; the dialogs component
-- resolves missing entries over its shared default look (step 6).
--
-- 4a's dialog (DialogPane): a window of its own size on the 1024 x 768 screen; most of the NPC dialogs draw a picture
-- (DLGxxx.EPF, control 0) as their whole window and image buttons on it (ImageButtonControlPane: BUTT001.EPF, id x 4 +
-- 0 normal, 1 pressed, 2 disabled, 3 focused); the texts are font 0 (BARAM00.EFT) in colour 0x80. A dialog opens at its
-- placement slot (slot 1, centred on (512, 384), DialogPane::AddToLayer with its clamps). Ours: the window at that place
-- on the 7.x screen, scaled with it (the screen's scale and letterbox, as interfaces/7x/panels/screen).
--
-- s6-interface-7x-b (round 8, the interface separation's step 5: docs/development/interface-separation.md, the row for
-- this file): the drawing helpers (X) are the original client's kit, made with 7.x's skin and its screen
-- (interfaces/7x/draw.lua, shared with 7.x's panels); they were this file's before, and s6-devtools moved them to
-- interfaces/original/dialogkit.lua with neutral field names (win.lookEntry for win.x7, win.screenX and win.screenY for
-- win.x7x and win.x7y, and the controls' own). The alerts are the kit's too (interfaces/original/alerts.lua). What stays
-- here is 7.x's: its windows, their placement, opening and focus mark.
-- Round 9, step 6: the component resolves missing entries, selects the window's look and supplies its entry;
-- this file no longer reaches Modern or the component's private building/focus state.
-- s6-ui-core (round 85): the XML twin's; what every window shares (its placement, its open sound) is look.xml's and each
-- family's windows are its own XML file's (npc.xml...), read as data (core/xml.md; the windows themselves are the
-- dialogs component's, made by its renderers); entry.lua makes a family's entries from them.

local fallback = TK.Dialogs.DefaultLook()
local Screen = require("interfaces.screen")
local S = require("interfaces.7x.skin")
local D = TK.Xml.Data("look.xml")

local L = {} -- Missing entries are resolved by the dialogs component, before it selects this drawing.
-- Wire policy consumed by shared K.Edit: 4a Activate 0x00498ED0 selects all, then OnMouseEvent 0x00590DE0 places
-- the native caret in the same pointer event. Changing this changes the text a later command sends to the server.
L.NativePointerCaret = true
local X = require("interfaces.7x.draw")
X.Fallback = fallback -- the look of the windows 7.x leaves (the kit's alerts ask it)

-- ----- what every 7.x dialog shares -----

--- A dialog's window for a 7.x entry (the component supplies entry and class): the kit's (X.Window; its title kept but
--- not drawn).
function L.Window(width, height, title, entry, class)
    return X.Window(width, height, title, entry)
end

--- Where a 7.x dialog opens: its placement slot (slot 1 and the others: mode 1, centred on (512, 384) on 1024 x 768:
--- Config::InitializeDefaults), moved inside by DialogPane::AddToLayer's clamps (bottom above 50 or top below 430; right
--- above 50 or left below 590), on the 7.x screen and at its scale. An entry may centre a window elsewhere
--- (entry.centre(win): the centre and whether the clamps apply: the alerts'). Its place on the 7.x screen is kept
--- (win.screenX, win.screenY: the kit's slide and alerts read it), for a dialog centred on another. Drawing only.
function L.Place(win)
    local s, left, top = Screen.Fit(S.WIDTH, S.HEIGHT)
    win:SetScale(s)
    local w, h = math.floor(win:GetWidth() + 0.5), math.floor(win:GetHeight() + 0.5)
    local P = D.PLACE
    local cx, cy, clamp = P.x, P.y, true
    if win.lookEntry.centre then cx, cy, clamp = win.lookEntry.centre(win) end
    local x, y = cx - math.floor(w / 2), cy - math.floor(h / 2)
    if clamp then
        if y + h < P.bottom then y = P.bottom - h elseif y > P.top then y = P.top end
        if x + w < P.right then x = P.right - w elseif x > P.left then x = P.left end
    end
    win.screenX, win.screenY = x, y
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (left + x * s) / s, -(top + y * s) / s)
end

--- Whether a window is sliding open now (the tests wait for its place: DialogPlayBase.SlidesDone): the kit's (X.Sliding),
--- whose windows this look slides open (L.Open).
function L.Sliding() return X.Sliding() end

--- A 7.x window opening: at its place, with the open sound (DialogPane::AddToLayer 0x0049DFD0 plays sample 0x198 at
--- volume 100 as it attaches any dialog, the alerts too: TK.Game.Sound.PlayEffect); an entry of a fixed size
--- that slides open (entry.slide: true for the pickers, or a test of the window and its view: the boards' first window)
--- slides now, the others when their size is known (their fit). The popups are 4a's plain panes (no sound): the default
--- open places them through their entry. Drawing and sound only.
function L.Open(win, view, i, layout)
    -- Menu, Player, Timer and Transfer build plain panes instead of L.Window; their entry places them.
    if not win.lookEntry then return X.Fallback.Open(win, view, i, layout) end
    L.Place(win)
    TK.Game.Sound.PlayEffect(D.OPEN_SOUND)
    local slide = win.lookEntry.slide
    if type(slide) == "function" then slide = slide(win, view) end
    if slide then X.SlideOpen(win) end
end

--- The focus's mark: on a 7.x image button its focused picture (offset 3) in place of the normal one while it has the
--- focus; nothing on 7.x's other controls (4a's lists and edits draw none); the default edge on plain panes.
function L.FocusEdge(frame, win)
    if not (win and win.lookEntry) then return X.Fallback.FocusEdge(frame) end
    if frame.x7mark then return frame.x7mark end -- s6-interface-7x (round 2): a control's own (the Macro Setup's row frame)
    local mark = {}
    function mark:SetShown(on)
        if frame.normalPicture then
            frame:GetNormalTexture():SetTexture((on and frame.focusedPicture) or frame.normalPicture)
        end
    end
    return mark
end

-- The families drawn so far, in this order (s6-interface-7x-b, round 7: the music dialog and the paper, misc.lua; the
-- head choice, heads.lua; any dialog without a window of its own, generic.lua). The alerts are the original client's
-- (s6-interface-5x round 15, the separation's step 9: interfaces/7x/dialogs/alerts.lua, which forwarded to it, went).
for _, family in ipairs({ "7x.dialogs.npc", "7x.dialogs.merchant", "original.alerts", "7x.dialogs.exchange",
    "7x.dialogs.panes", "7x.dialogs.boards", "7x.dialogs.social", "7x.dialogs.web", "7x.dialogs.album", "7x.dialogs.shops",
    "7x.dialogs.fitting", "7x.dialogs.options", "7x.dialogs.macros", "7x.dialogs.misc", "7x.dialogs.heads",
    "7x.dialogs.generic" }) do
    require("interfaces." .. family)(L, X)
end

return L
