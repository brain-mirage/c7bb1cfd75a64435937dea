-- G2's passive inventory/spell drag labels. Each native page owns its frame and supplies
-- its skin and row origin; the shared inventory/spell handlers still own all actions.
-- 4a HelpPane.cpp: WillBeChangedItemPane 0x004C78E0/0x004C7BB0 and
-- WillBeChangedSpellPane 0x004C7F90/0x004C80E0 draw transparent labels with the
-- slot letter and native name. 5.x uses its existing font/palette and half-size game art.
local H = __tk
local U = TK.Util
local Item = require("interfaces.original.itempicture")
local D = {}

--- One label for a page. The top-level passive frame follows the press's grab offset
--- across the screen; hiding/unloading the page closes its label as well.
--- f.kind and f.slot are the last press's. f.held is true from that press until its release
--- or a key that ends 4a's selection (the shared slot control's PressSelected), even once a key
--- has hidden the label: 4a deletes the label on such a key, but its pane keeps the selection on
--- Page Up/Page Down. f.moved is true once the pane has repainted the selection since the press:
--- the pointer's first move, or a key the pane keeps. A page that paints the press's selection
--- sets f.onChange; it is called when the label shows, on the first move, on a key while held,
--- when it hides and at the release. Paint only.
function D.New(owner, S, artScale, itemNameColour)
    local f = CreateFrame("Frame", nil, UIParent)
    -- s6-ui-core (round 85): the page's panel's, destroyed with it. CreateFrame leaves a frame this shared file makes on
    -- UIParent to no panel (a shared singleton's rule: Components:FrameOwner), so each unload left the label behind.
    TK.Components:Adopt(f, TK.Components:Owner())
    f:SetFrameStrata("TOOLTIP")
    f:EnableMouse(false)
    f:Hide()
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.letter = f:CreateFontString(nil, "OVERLAY")
    f.letter2 = f:CreateFontString(nil, "OVERLAY")
    f.name = f:CreateFontString(nil, "OVERLAY")

    local function text(fs, value, x, y, colour)
        S.Text(fs, colour)
        fs:SetWordWrap(false)
        fs:SetJustifyH("LEFT")
        fs:SetText(value)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
        fs:Show()
        return x + (S.TextWidth(value) or fs:GetStringWidth())
    end

    local function place()
        local x, y = U.CursorRoot()
        -- A dyed label is outside the active panel's palette repaint. 4a's
        -- WillBeChangedItemPane 0x004C7F00 invalidates it on pointer movement.
        -- This refresh changes only its picture, never event ownership or commands.
        if f.repaint and (x ~= f.lastPointerX or y ~= f.lastPointerY) then f.repaint() end
        -- 4a's panes repaint a held selection on the first pointer move after the press
        -- (NewInventoryPane 0x004ECB50 :983-996, NewSpellInventoryPane 0x0057D9C0 :692-707).
        if not f.moved and (x ~= f.pointerX or y ~= f.pointerY) then
            f.moved = true
            if f.onChange then f.onChange() end
        end
        f.lastPointerX, f.lastPointerY = x, y
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", f.left + (x - f.pointerX) / f.scale,
            f.top + (y - f.pointerY) / f.scale)
    end

    f:SetScript("OnUpdate", place)
    f:SetScript("OnHide", function()
        if TK.Cursor.preview == f then TK.Cursor:SetPreview(nil) end
        if f.onChange then f.onChange() end
    end)
    owner:HookScript("OnHide", function() f.held = false f:Hide() end)

    -- These watches only dismiss paint. WIRE: 4a's label handlers 0x004C7F00 and
    -- 0x004C8250 return false on release and 0x004C7F50/0x004C8290 return false
    -- on keys; the list/game keeps the event. Taking it would change what the server sees.
    f:SetWatchesKeys(true)
    TK.On("GLOBAL_MOUSE_UP", function(_, button)
        if button ~= "LeftButton" then return end
        local held = f.held
        f.held = false
        if f:IsShown() then f:Hide() elseif held and f.onChange then f.onChange() end
    end)
    -- s6-interface-5x (Native29): the selection a key leaves. NewInventoryPane::HandleKeyOrTextEvent
    -- 0x004EC920 keeps it on unmodified Page Up/Page Down and repaints the pane (InventoryPane.cpp:
    -- 897, :923), and on 'i', whose ToggleExpandedMode 0x004EE5A0 reactivates it (OnActivate);
    -- NewSpellInventoryPane 0x0057D8D0 alike (:642, :651; '+'). The shared slot control has applied
    -- that rule by now (its GAME_KEY_DOWN listener was registered first, at load), so a selection
    -- still alive was kept and is painted from here on; one that ended stops being painted. Paint
    -- only: the key, the selection and the carry stay the shared control's.
    TK.On("GAME_KEY_DOWN", function()
        if not f.held then return end
        local game = f.kind == "spell" and TK.Game.Spells or TK.Game.Inventory
        if game.PressSelected() then f.moved = true else f.held = false end
        if f.onChange then f.onChange() end
    end)
    TK.On("GLOBAL_KEY_DOWN", function(_, key)
        -- KeyNames supplies binding names rather than 4a's translated characters.
        -- OriginalKeys.Code maps I to lower-case i unless Shift is held; '+' is
        -- NUMPADPLUS with any modifiers or SHIFT-= without Ctrl/Alt. Every type-8
        -- key-down, including repeats, follows HelpPane's dismissal rule above.
        local bare = U.BareKey(key)
        local shift = key:find("SHIFT-", 1, true)
        local keep = f.kind == "spell" and (bare == "NUMPADPLUS" or
            (bare == "=" and shift and not key:find("CTRL-", 1, true) and not key:find("ALT-", 1, true))) or
            (f.kind ~= "spell" and bare == "I" and not shift)
        if not keep then f:Hide() end
    end)

    --- Add paint after the existing control's press callback. layout(button) returns the
    --- page-local native row origin and list/grid mode; it never changes control geometry.
    function f:Attach(button, layout)
        button:HookScript("OnMouseDown", function(b, which, double)
            -- WIRE: NewInventoryPane 0x004ECB50/NewSpellInventoryPane 0x0057DD40
            -- create labels on a single left press, with no live dialog, and a spell's only while no
            -- spell input is up (0x0057D9C0 :780, Native28). Existing handlers decide selection/carry/
            -- cast; these conditions affect paint only and never send.
            if which ~= "LeftButton" or double or H:ActiveDialogs() > 0 or not b.slot or TK.Cursor:Get() then return end
            local kind, x, y = layout(b)
            if kind == "spell" and H:IsSpellInputActive() then return end
            local ok, name, count, meta, iconId, colour
            if kind == "spell" then ok, name = H:GetSpellSlot(b.slot)
            else ok, name, count, meta, iconId, colour = H:GetItemSlot(b.slot) end
            if not ok then return end
            local previous = TK.Cursor.preview
            if previous and previous ~= f then previous:Hide() end
            f.kind, f.slot = kind, b.slot
            f.scale = owner:GetEffectiveScale()
            f:SetScale(f.scale)
            f.pointerX, f.pointerY = U.CursorRoot()
            f.lastPointerX, f.lastPointerY = f.pointerX, f.pointerY
            f.held, f.moved = true, false
            f.repaint = nil
            local left, bottom, _, height = U.RootRect(owner)
            local boxX, boxY, w, h = x, y, 160, 12
            f.icon:Hide() f.letter:Hide() f.letter2:Hide() f.name:Hide()
            local letter = H:SlotLetter(b.slot)
            if kind == "spell" then
                text(f.letter, letter, 1, 0, 12)
                text(f.letter2, letter, 0, 0, 12)
                text(f.name, name, 25, 0, 0x8F)
                f.name:SetWidth(135)
            else
                local key, iw, ih = TK.Art.Icon(iconId)
                if key then
                    local has, fw, fh = H:GetArtFrameSize(key)
                    if has then iw, ih = fw, fh end
                else iw, ih = 0, 0 end
                iw, ih = math.floor(iw * artScale), math.floor(ih * artScale)
                if kind == "list" then
                    w, h = 170, math.max(16, math.floor(ih / 2))
                    boxX = math.min(x, x - math.floor(math.floor(iw / 2) / 2) + 6)
                    boxY = y - math.floor(h / 2) - 6
                    local dx, dy = x - boxX, y - boxY
                    local function paint() Item(f.icon, f, iconId, dx + 6, dy - 6, artScale / 2, nil, colour, true) end
                    paint()
                    if colour and colour ~= 0 then f.repaint = paint end
                    text(f.letter, letter .. "  ", dx + 25, dy - 11, 12)
                    local nextX = text(f.letter2, letter .. "  ", dx + 24, dy - 11, 12)
                    -- 5.x's item pane has a black background and supplies its native
                    -- list-name colour; 7.x retains 4a's black label name.
                    text(f.name, name, nextX, dy - 11, itemNameColour or 0x80)
                    f.name:SetWidth(math.max(1, w - nextX))
                else
                    w, h = iw + math.floor(math.max(0, 43 - iw) / 2), ih + math.floor(math.max(0, 43 - ih) / 2)
                    local function paint()
                        Item(f.icon, f, iconId, math.floor(math.max(43, iw) / 2), math.floor(math.max(43, ih) / 2), artScale, nil, colour, true)
                    end
                    paint()
                    if colour and colour ~= 0 then f.repaint = paint end
                    text(f.letter, letter, 1, 0, 12)
                    text(f.letter2, letter, 0, 0, 12)
                end
            end
            f:SetSize(w, h)
            f.left = left / f.scale + boxX
            f.top = (bottom + height) / f.scale - boxY
            place()
            f:Show()
            TK.Cursor:SetPreview(f)
            if f.onChange then f.onChange() end
        end)
    end
    return f
end

return D
