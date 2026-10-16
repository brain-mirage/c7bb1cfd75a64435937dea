-- s6-modular-g (interfaces; docs/development/interfaces.md, "The dialogs: geometry is the look's, behaviour
-- is shared"): the default look of the dialogs, today's Modern numbers (step 6 of the interface separation, round 46: the
-- dialogs component's own, which any interface's look falls back to for an entry it lacks; Modern uses it as it is, with
-- only what names its own frames in interfaces/modern/dialogs/). A renderer (components/dialogs/) makes its window's parts
-- with their control indexes, fills them from the dialog model and passes the player's input on: what a dialog does
-- and sends, written once. It asks the look for its window's size and calls it where the parts are placed, in the same
-- order as before on each frame; another interface's look gives the same entries with its own numbers (7.x's from
-- Source-5, phase 4). A look only sizes, places and draws: nothing in it reaches the model or the server.
--
-- This file holds what every dialog shares (the window, the portrait, the focused control's edge, where a window opens)
-- and the placing helpers; each family's entries are in the file of its renderer's name, by the renderer's look name.

-- ----- placing helpers, for the families' files -----

local P = {}

--- A region across the window from left in to right in, its top at top (from the window's top); with clear, its
--- earlier points are dropped first (a place that changes with the dialog).
function P.Across(region, win, left, right, top, clear)
    if clear then region:ClearAllPoints() end
    region:SetPoint("TOPLEFT", win, "TOPLEFT", left, top)
    region:SetPoint("TOPRIGHT", win, "TOPRIGHT", -right, top)
end

--- Buttons in a row along the window's bottom, from right to left: the first right in and bottom up from the bottom
--- right corner, each next gap to the left of the one before.
function P.Row(win, buttons, right, bottom, gap)
    buttons[1]:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -right, bottom)
    for i = 2, #buttons do buttons[i]:SetPoint("RIGHT", buttons[i - 1], "LEFT", -gap, 0) end
end

--- A region at a point of the window's top left corner, x across and y down (negative).
function P.At(region, win, x, y)
    region:SetPoint("TOPLEFT", win, "TOPLEFT", x, y)
end

--- A region centred along the window's bottom, x from its middle, bottom up.
function P.Bottom(region, win, x, bottom)
    region:SetPoint("BOTTOM", win, "BOTTOM", x or 0, bottom)
end

-- ----- what every dialog shares -----

--- s6-characters (round 47, merging step 5's skins): the default look drawn with W, TK.UI's widgets bound to a skin
--- (TK.UI.With). The component's default uses the shared default finish (interfaces/defaultskin.lua);
--- Modern builds its own capsule, and a restyle replaces its skin (interfaces/modern/skin.lua; Modern's look:
--- interfaces/modern/dialogs/init.lua), so its restyle moves its dialogs and leaves the others' fallbacks alone (the
--- plan's Q2 and Q5). Drawing only.
local function Build(W)
    local L = {}

    --- A dialog's window: an opaque panel with its title at the top, movable, opening near the screen's centre. The kit
    --- (K.Window) makes it take the pointer and puts it on the dialogs' strata; title is the dialog's own. A look's
    --- Window also gets the renderer's entry and the dialog's class (step 6), which this one does not need.
    function L.Window(width, height, title)
        local f = W.Panel(UIParent, nil)
        f:SetSize(width, height)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        f:SetMovable(true)
        f:SetClampedToScreen(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        f.title = W.Label(f, title or "", 15, W.gold)
        f.title:SetPoint("TOP", f, "TOP", 0, -10)
        return f
    end

    --- Where a dialog's window opens (i: its place in the stack, layout: its entry). A pane with a place of its own has
    --- its entry's open(win, view); any other opens near the screen's centre, its entry's x and y (default 60 above the
    --- centre) from it, each newer dialog of the stack a step down and right of the one before, so they never hide each
    --- other wholly. (An entry's place(win) places its parts when the window is built.)
    function L.Open(win, view, i, layout)
        if layout.open then
            layout.open(win, view)
            return
        end
        local dx, dy = layout.x or 0, layout.y or 60
        win:SetPoint("CENTER", UIParent, "CENTER", dx + (i - 1) % 4 * 12, dy - (i - 1) % 4 * 12)
    end

    -- The portrait (the kit's K.ShowPicture): 4a's 74 x 108 pane (ObjectImageControlPane) at the window's top left; the
    -- text beside it starts textX further right.
    L.Portrait = { width = 74, height = 108, left = 16, top = -34, textX = 90 }

    --- The lists (the kit's K.List makes them and their rows, and keeps what a press on them does): s6-characters
    --- (round 46, step 6) moved their drawing here from the kit, unchanged. A look that draws its lists otherwise
    --- restyles these parts (list.styleRow, list.paintRow, sf.bg).
    L.List = {
        --- The list's background, under its rows (returned: the kit keeps it as sf.bg).
        background = function(sf)
            local bg = sf:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(sf)
            bg:SetColorTexture(0, 0, 0, 0.35)
            return bg
        end,
        --- A row's parts the kit and the renderers use: its selection's bar (row.sel, which the kit shows), its hover
        --- (row.hl) and its text (row.text).
        row = function(row)
            row.sel = row:CreateTexture(nil, "BACKGROUND")
            row.sel:SetAllPoints(row)
            row.sel:SetColorTexture(0.25, 0.4, 0.8, 0.5)
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(row)
            hl:SetColorTexture(1, 1, 1, 0.08)
            row.hl = hl -- s6-modular-g: a look's rows may have no hover
            row.text = W.Label(row, "", 13, W.white, "LEFT")
            row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        end,
    }

    --- The edge round the control the dialog's focus is on (the kit's K.ShowState shows and hides it; win: the
    --- control's window, step 6).
    function L.FocusEdge(frame)
        local edge = CreateFrame("Frame", nil, frame)
        edge:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
        edge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
        edge:SetBackdrop({ edge = { W.gold[1], W.gold[2], W.gold[3], 0.9 } })
        return edge
    end

    -- The families' entries, by their renderers' files.
    for _, family in ipairs({ "alerts", "npc", "merchant", "exchange", "bulletin", "social", "misc", "shops", "web",
                              "panes", "collection", "fitting", "generic", "chatcolor" }) do
        require("components.dialogs.look." .. family)(L, P, W)
    end
    L.With = Build
    return L
end

return Build(require("interfaces.defaultskin").UI)
