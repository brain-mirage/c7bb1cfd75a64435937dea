-- Action bars, Bartender-like. Bar b's button i shows action slot (b - 1) * 12 + i. A button shows the action's
-- icon (an item's picture from the original's ITEM.EPF when the game's data is installed; a coloured square with the
-- first letter for spells, which have no pictures in the original, and for items without data), its hotkey, an
-- item's count, the
-- action's name as "macro text" (hidden by default), and its aether: the game's word for a cooldown, shown as a
-- large centred number (as OmniCC does) over the clock sweep.
--
-- As WoW's bars (the owner, 2026-10-01; plan 5.11): only bar 1, across the bottom, is on by default; the others are
-- turned on in the settings, and keep their buttons while off. A character starts with empty bars, and a spell it has
-- not had before goes onto the first empty button of the bars that are on (never an item). An item on a bar is the item,
-- not its bag slot (core/cursor.lua): it shows the total count, is darkened at 0 and then does nothing (its press sends
-- nothing), and comes back when the item is in the bag again; its press uses the item's first slot (1C, as 4a's use of
-- that slot). A spell on a bar is the spell, not its book slot (the owner, 2026-10-02; core/cursor.lua's
-- TK.FollowSpells): rearranging the book moves nothing on the bars, and a spell the book has lost is darkened and
-- silent until it is back.
--
-- Clicking a button or pressing its key runs its action (TK.Actions): offline a mock cast or use in the MockWorld;
-- online the action goes to the rules, which send nothing until the Spells and Items rules exist. Actions are dragged
-- between buttons (PickupAction / PlaceAction); with Button Lock on, dragging needs Shift, as WoW's "Lock Action
-- Bars". Spells from the spell book and items from the bag are dragged onto the buttons the same way.

--
-- s6-modular-g (round 19, the separation's step 8; interface-separation.md 5.9): the original's 30 hotkeys (keys 1-0, with
-- Ctrl and Alt) are the game layer's (TK.Game.Hotkeys: their carriers, the slots' attach and press, what goes onto the
-- slots by itself). Bars 1-3's buttons 1-10 draw those slots and bind through the carriers' commands (C.ButtonCommand,
-- settings.lua, with the default keys); the bars can be turned off with their component and the hotkeys still act.

local C = TK.GetComponent("actionbars")
local H = __tk
local U = TK.Util
local K = TK.Game.Hotkeys
local W = require("interfaces.modern.skin").UI -- s6-ui-core (round 62): Modern's skin, for the shared slot (W.SlotArt)
local Mark = require("interfaces.modern.slotmark") -- s6-ui-core (round 83): the red edge, shared with the book and the wheel

C.bars = {}

function C:BarDB(id) return self:DB().bars[tostring(id)] end

-- ----- buttons -----

--- A button's slot background (the owner, 2026-10-01: "the hotbar usually has the buttons with a black background at
--- 50-75 % transparency by default"): black, at the UI transparency (TK.UI.PanelAlpha; s6-ui-core round 53: the owner's
--- 25 % for every panel), or at its bar's own where its settings untick Use Global Transparency.
function C:ColourSlot(b)
    b.bg:SetVertexColor(0, 0, 0, TK.UI.PanelAlpha(TK.UI.OwnTransparency(self:BarDB(b.bar.id))))
end

local function showTooltip(b)
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    local action = TK.ActionAt(b.action)
    local kind, slot = action and action.kind, TK.ActionSlot(action)
    local name, _, _, count = TK.ActionInfo(action)
    local key = GetBindingKey(b.command)
    if TK.KeyBindMode.active then
        GameTooltip:AddLine(b.label, 1, 0.82, 0)
        GameTooltip:AddLine(key and ("Bound to " .. key) or "Not bound", 1, 1, 1)
        GameTooltip:AddLine("Press a key to bind it; Escape clears it.", 0.6, 0.9, 0.6)
    elseif name and kind == "macro" then
        GameTooltip:AddLine(name, 1, 1, 1)
        GameTooltip:AddLine("Text macro: says this line", 0.8, 0.8, 0.8)
        if key then GameTooltip:AddLine("Key: " .. key, 0.5, 0.8, 1) end
    elseif name and kind == "usermacro" then
        TK.MacroTooltip(action, key) -- s6-macros: the macro's, or (#showtooltip) what it would do
    elseif name then
        GameTooltip:AddLine(name, 1, 1, 1)
        local letter = slot and H:SlotLetter(slot) or "-"
        GameTooltip:AddDoubleLine(kind == "spell" and "Spell" or "Item", "Slot " .. letter, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        if kind == "spell" then
            TK.AddSpellCostLine(name)
            TK.ManaPreview.Show(name)
        end
        if kind == "item" then GameTooltip:AddLine("Count: " .. count, 0.8, 0.8, 0.8) end
        if kind == "item" and count == 0 then
            GameTooltip:AddLine("None in the bag: the button does nothing until you have one again.", 1, 0.5, 0.5)
        elseif kind == "spell" and not slot then
            GameTooltip:AddLine("Not in your spell book: the button does nothing until it is back.", 1, 0.5, 0.5)
        end
        if key then GameTooltip:AddLine("Key: " .. key, 0.5, 0.8, 1) end
        GameTooltip:AddLine("Drag to move it to another button.", 0.5, 0.5, 0.5)
    else
        GameTooltip:AddLine(b.label, 1, 0.82, 0)
        GameTooltip:AddLine("Empty. Drag a spell or item here.", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

local function makeButton(bar, index)
    local name = "TKActionBar" .. bar.id .. "Button" .. index
    local b = CreateFrame("Button", name, bar.frame)
    b.bar, b.index = bar, index
    b.action = C.Slot(bar.id, index)
    -- s6-modular-g (round 19, step 8): the binding it binds through, a carrier's for the original's hotkeys
    b.command = C.ButtonCommand(bar.id, index)
    b.label = "Bar " .. bar.id .. " Button " .. index
    -- A click goes on the hotkey path; a bar that is off keeps its keys (the owner, 2026-10-03). Wire: TK.Game.Hotkeys.
    K.MakeHotkey(b)
    if b.command ~= "CLICK " .. name then K.SetFace(b.action, b) end -- the carrier's key shows pushed here
    b:SetSize(C.BUTTON_SIZE, C.BUTTON_SIZE)

    -- s6-ui-core (round 62): the shared slot's picture, an action button's edge, the light; its box's colour the bar's
    -- (ColourSlot). The icon: the original's item picture at its own size, or a placeholder square with the letter
    -- (spells have no pictures in the original). The gloss, the pushed look and the cooldown cover the same inset square.
    b.bg, b.icon, b.border = W.SlotArt(b, { edge = W.slotActionEdge })
    C:ColourSlot(b)

    b.gloss = b:CreateTexture(nil, "ARTWORK", nil, 2)
    b.gloss:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.gloss:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.gloss:SetTexture("tk:gloss")

    b.glyph = b:CreateFontString(nil, "ARTWORK", nil, 3)
    b.glyph:SetFont(22, "OUTLINE")
    b.glyph:SetTextColor(1, 1, 1, 0.95)
    b.glyph:SetPoint("CENTER", b, "CENTER", 0, 1)

    local pushed = b:CreateTexture(nil, "OVERLAY", nil, 1)
    pushed:SetAllPoints(b.gloss)
    pushed:SetColorTexture(0, 0, 0, 0.4)
    b:SetPushedTexture(pushed)

    -- The cooldown above the icon, then the texts above the cooldown so they stay readable.
    b.cooldown = CreateFrame("Cooldown", name .. "Cooldown", b)
    b.cooldown:SetAllPoints(b.gloss)
    b.cooldown:SetFrameLevel(b:GetFrameLevel() + 1)
    b.cooldown:SetCountdownFontSize(24)
    -- The icon's letter steps back while the aether number is shown over it; s6-ui-core (round 82): the aether's red edge
    -- goes with it.
    b.cooldown:SetScript("OnCooldownDone", function()
        b.glyph:SetAlpha(0.95)
        local kind, slot = C:ShownAction(b)
        C:UpdateMark(b, kind, slot, false)
    end)

    b.texts = CreateFrame("Frame", nil, b)
    b.texts:SetAllPoints(b)
    b.texts:SetFrameLevel(b:GetFrameLevel() + 2)

    b.hotkey = b.texts:CreateFontString(nil, "OVERLAY")
    b.hotkey:SetFont(12, "OUTLINE")
    b.hotkey:SetTextColor(0.85, 0.85, 0.85, 1)
    b.hotkey:SetJustifyH("RIGHT")
    b.hotkey:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -3)

    b.count = b.texts:CreateFontString(nil, "OVERLAY")
    b.count:SetFont(13, "OUTLINE")
    b.count:SetTextColor(1, 1, 1, 1)
    b.count:SetJustifyH("RIGHT")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)

    b.name = b.texts:CreateFontString(nil, "OVERLAY")
    b.name:SetFont(10, "OUTLINE")
    b.name:SetTextColor(1, 1, 1, 0.9)
    b.name:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 3)
    b.name:SetJustifyH("LEFT")

    b.bindOverlay = b.texts:CreateTexture(nil, "OVERLAY", nil, -1)
    b.bindOverlay:SetAllPoints(b)
    b.bindOverlay:SetColorTexture(0.2, 0.9, 0.3, 0.35)
    b.bindOverlay:Hide()

    b:RegisterForDrag("LeftButton")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- A click (or Modern's own key) presses the slot as the game layer does (wire: TK.Game.Hotkeys.Press).
    b:SetScript("OnClick", function(self, button)
        if K.Press(self, button) == "placed" then
            C:UpdateAllButtons()
            showTooltip(self) -- s6-macros: the placed action's tooltip, not the one from before the drop
        end
    end)
    b:SetScript("OnDragStart", function(self)
        if TK.KeyBindMode.active then return end
        if TK.DB:Global().buttonLock and not IsShiftKeyDown() then return end
        if not HasAction(self.action) then return end
        PickupAction(self.action)
        C:UpdateAllButtons()
    end)
    b:SetScript("OnReceiveDrag", function(self)
        if not GetCursorInfo() then return end
        PlaceAction(self.action)
        C:UpdateAllButtons()
        showTooltip(self) -- s6-macros: the dropped action's tooltip, not the empty button's
    end)
    b:SetScript("OnEnter", function(self)
        if TK.KeyBindMode.active then self.bindOverlay:Show() end
        showTooltip(self)
    end)
    b:SetScript("OnLeave", function(self)
        self.bindOverlay:Hide()
        GameTooltip:Hide()
        TK.ManaPreview.Hide()
    end)

    TK.Bindings:RegisterBindable(b, b.command, b.label)
    return b
end

-- Head note 44: with spell icons animating, each shown button holding a spell draws its icon's frame showing now.
-- s6-optimize (round 10): the action (a Lua lookup) is looked at first, so only spell buttons ask C# whether they show.
-- s6-modular-g (round 16): registered by name (TK.SetSpellIconAnimator), not written into the global table.
-- s6-interface-5x (round 13's hotfix): only the bars that are on.
TK.SetSpellIconAnimator("actionbars", function()
    for _, bar in ipairs(C.bars or {}) do
        if C:BarDB(bar.id).enabled then
            for _, b in ipairs(bar.buttons) do
                local action = TK.ActionAt(b.action)
                if action and action.kind == "spell" and b:IsVisible() then
                    local _, art, missing = TK.UI.ActionIcon(b.icon, b.glyph, b, action, C.BUTTON_SIZE - 6, 3)
                    b.gloss:SetShown(not art)
                    -- A spell the book has not stays darkened through the animation (review r5 finding 3).
                    if missing then b.icon:SetVertexColor(0.3, 0.3, 0.3, 1) end
                end
            end
        end
    end
end)

--- Refreshes a button from its action: icon, texts, cooldown, and whether it is shown. keys: the bindings' first keys
--- (TK.Bindings:PrimaryKeys()) when many buttons are refreshed at once.
function C:UpdateButton(b, keys)
    local db = self:BarDB(b.bar.id)
    -- The button carries what a click of it (or its own key) runs, frozen when the press begins (wire: TK.Game.Hotkeys.
    -- Attach). An item none of which is left, or a spell the book no longer has: shown darkened, and it runs nothing.
    local action, none = K.Attach(b, b.action)
    local kind, slot = action and action.kind, TK.ActionSlot(action)
    local name, _, _, count = TK.ActionInfo(action)
    -- s6-interface-5x (round 13's hotfix, Astra's self-review 13-2): a bar that is off keeps only what its keys run
    -- (above); its look is drawn again when it is turned on (ApplyBar), its slot's colour too (13-3)
    if not db.enabled then return end
    self:ColourSlot(b)
    -- s6-macros: a macro's button counts and shows the aether of what it would do (#showtooltip), if anything.
    if kind == "usermacro" then kind, slot = TK.MacroShownAction(action.id) end

    if name then
        local _, art = TK.UI.ActionIcon(b.icon, b.glyph, b, action, C.BUTTON_SIZE - 6, 3)
        b.gloss:SetShown(not art)
        if none then
            b.icon:SetVertexColor(0.3, 0.3, 0.3, 1)
            b.glyph:SetTextColor(0.45, 0.45, 0.45, 0.95)
        else
            b.glyph:SetTextColor(1, 1, 1, 0.95)
        end
        -- An item on the bar shows its total count, 0 included; a macro's shown item only a stack's.
        local hasCount = action.kind == "item" or (kind == "item" and count > 1)
        b.count:SetText(hasCount and tostring(count) or "")
        -- The name is the "macro text"; an item's count takes the bottom of the button instead.
        local short = name:match("^(%S+)") or name
        -- Eight characters, not bytes: a macro's line may have any (a byte cut splits one).
        local cut = utf8.offset(short, 9)
        if cut then short = short:sub(1, cut - 1) end
        b.name:SetText(hasCount and "" or short)
        C:UpdateAether(b, kind, slot)
    else
        b.icon:SetTexture("")
        b.glyph:SetText("")
        b.gloss:Hide()
        b.count:SetText("")
        b.name:SetText("")
        b.cooldown:Clear()
        self:UpdateMark(b) -- s6-ui-core (round 82)
    end
    b.name:SetShown(not db.hideMacroText)

    local hotkey
    if keys then hotkey = keys[b.command] else hotkey = GetBindingKey(b.command) end
    b.hotkey:SetText(U.ShortKey(hotkey))
    b.hotkey:SetShown(not db.hideHotkey)

    b.cooldown:SetDrawSwipe(db.showCooldownClock)
    b.cooldown:SetDrawEdge(db.showCooldownClock)
    b.cooldown:SetHideCountdownNumbers(not db.showCooldownNumbers)

    -- Empty buttons show only with Button Grid (on by default, so the bar's slots show their black background, as WoW's
    -- bar does), while an action is on the cursor, or while binding keys.
    local inRange = b.index <= (db.buttons or 12)
    local showEmpty = db.buttonGrid or GetCursorInfo() ~= nil or TK.KeyBindMode.active or TK.EditMode.unlocked
    b:SetShown(inRange and (name ~= nil or showEmpty))
end

function C:UpdateAllButtons()
    -- s6-optimize: the bindings' first keys once for every button, not a scan of all bindings per button.
    local keys = TK.Bindings:PrimaryKeys()
    for _, bar in ipairs(self.bars) do
        for _, b in ipairs(bar.buttons) do self:UpdateButton(b, keys) end
    end
end

--- Shows an action's aether: the sweep and the number, with the icon's letter dimmed under the number.
function C:UpdateAether(b, kind, slot)
    local ok, start, duration
    if (kind == "spell" or kind == "item") and slot then ok, start, duration = H:GetSlotCooldown(kind, slot) end
    if ok then
        b.cooldown:SetCooldown(start, duration)
        local numbers = self:BarDB(b.bar.id).showCooldownNumbers
        b.glyph:SetAlpha(numbers and 0.25 or 0.95)
    else
        b.cooldown:Clear()
        b.glyph:SetAlpha(0.95)
    end
    self:UpdateMark(b, kind, slot, ok) -- s6-ui-core (round 82)
end

--- The kind and slot a button's aether and mark are read from (the shared slotmark's, s6-ui-core round 83).
function C:ShownAction(b) return Mark.ShownAction(b.action) end

--- s6-ui-core (round 82; the owner, 2026-10-09): a button's edge turns red while what it holds cannot be used now, each
--- a switch of its bar's: a spell whose learned cost is more than the mana, or a spell or item in its aether (cooling).
--- Drawing only: a press goes as before (TK.Game.Hotkeys). Round 83: the rule and the drawing are the shared slotmark's.
function C:UpdateMark(b, kind, slot, cooling)
    b.cooling = cooling
    Mark.Draw(b, b.border, Mark.Unusable(kind, slot, cooling, self:BarDB(b.bar.id)), W.slotActionEdge)
end

--- s6-ui-core (round 82): the marks again as the mana changes, on the bars that are on.
function C:UpdateMarks()
    for _, bar in ipairs(self.bars) do
        if self:BarDB(bar.id).enabled then
            for _, b in ipairs(bar.buttons) do
                local kind, slot = self:ShownAction(b)
                self:UpdateMark(b, kind, slot, b.cooling)
            end
        end
    end
end

--- The aethers' sweeps and numbers. s6-interface-5x (round 13's hotfix): drawing only, so only on the bars that are on (a
--- bar turned on draws its own: ApplyBar).
function C:UpdateCooldowns()
    for _, bar in ipairs(self.bars) do
        if self:BarDB(bar.id).enabled then
            for _, b in ipairs(bar.buttons) do self:UpdateAether(b, self:ShownAction(b)) end
        end
    end
end

-- ----- what goes onto the bars by itself (WoW's) -----

--- The first button with no action on the bars that are on (only their shown buttons), or nil: where a new spell goes
--- (TK.Game.Hotkeys.PlaceNewSpells places it, as it names the items by the bag, in every interface).
function C:FirstEmptyButton()
    local actions = TK.Characters:Actions()
    for i = 1, C.MAX_BARS do
        local db = self:BarDB(i)
        if db.enabled then
            for j = 1, U.Clamp(math.floor(db.buttons or 12), 1, C.BUTTONS) do
                local slot = C.Slot(i, j)
                if actions[tostring(slot)] == nil then return slot end
            end
        end
    end
end

-- ----- bars -----

--- Lays a bar's buttons out in rows, with its padding and growth directions.
function C:LayoutBar(bar)
    local db = self:BarDB(bar.id)
    local n = U.Clamp(math.floor(db.buttons or 12), 1, C.BUTTONS)
    local rows = U.Clamp(math.floor(db.rows or 1), 1, n)
    local cols = math.ceil(n / rows)
    rows = math.ceil(n / cols)
    local size, pad = C.BUTTON_SIZE, db.padding or 2
    local w = cols * size + (cols - 1) * pad
    local h = rows * size + (rows - 1) * pad
    bar.frame:SetSize(math.max(w, 1), math.max(h, 1))
    for i, b in ipairs(bar.buttons) do
        b:ClearAllPoints()
        if i <= n then
            local r, c = math.floor((i - 1) / cols), (i - 1) % cols
            if db.growH == "LEFT" then c = cols - 1 - c end
            if db.growV == "UP" then r = rows - 1 - r end
            b:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", c * (size + pad), -r * (size + pad))
        end
    end
end

function C:ApplyBar(bar)
    self:LayoutBar(bar)
    for _, b in ipairs(bar.buttons) do self:UpdateButton(b) end
    TK.Visibility:Apply(bar.frame)
end

function C:OnEnable()
    for i = 1, C.MAX_BARS do
        local frame = CreateFrame("Frame", "TKActionBar" .. i, UIParent)
        local bar = { id = i, frame = frame, buttons = {} }
        frame.bar = bar
        for j = 1, C.BUTTONS do bar.buttons[j] = makeButton(bar, j) end
        self.bars[i] = bar
        TK.Visibility:Attach(frame, function() return self:BarDB(i) end)
        TK.EditMode:Register(frame, "bar" .. i, "Bar " .. i, C.defaultPositions[i], "bar" .. i,
            function() return self:BarDB(i).enabled end)
    end

    K.SetPlacer(function() return self:FirstEmptyButton() end)

    -- This runs for the bars that are off too, as a bar that is off keeps its keys while another is on (the owner,
    -- 2026-10-03): the buttons carry what their clicks and Modern's own keys run (UpdateButton: the action frozen at the
    -- press). Wire: a carried action left stale would use another slot or cast another spell than the press's (UserPane::
    -- UseCommandSlot 0x005A4530); changing this changes what the server sees. The original's hotkeys are the game layer's
    -- carriers since step 8 (s6-modular-g round 19), which it refreshes on the same events before this runs; so with
    -- every bar off this component is not loaded at all (step 11; s6-modular-g round 20). What is drawing alone skips the
    -- bars that are off (UpdateButton's look, UpdateCooldowns, the animator).
    local events = CreateFrame("Frame")
    for _, e in ipairs({ "ACTIONBAR_UPDATE_COOLDOWN", "BAG_UPDATE", "SPELLS_CHANGED", "UPDATE_BINDINGS",
                         "ACTIONBAR_SLOT_CHANGED", "TK_EDIT_MODE", "TK_KEYBIND_MODE", "PLAYER_ENTERING_WORLD",
                         "TK_PANEL_STYLE_CHANGED", "TK_DRAWING_STYLE_CHANGED",
                         "TK_SPELL_ICONS_CHANGED", -- s6-spell-icons: a spell's icon chosen in its editor
                         "UNIT_POWER" }) do -- s6-ui-core (round 82): the red edges as the mana changes
        events:RegisterEvent(e)
    end
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "ACTIONBAR_UPDATE_COOLDOWN" then
            self:UpdateCooldowns()
            return
        end
        if event == "UNIT_POWER" then
            if unit == "player" then self:UpdateMarks() end
            return
        end
        if event == "TK_PANEL_STYLE_CHANGED" then
            for _, bar in ipairs(self.bars) do
                if self:BarDB(bar.id).enabled then
                    for _, b in ipairs(bar.buttons) do self:ColourSlot(b) end
                end
            end
            return
        end
        self:UpdateAllButtons()
    end)
end

function C:ApplySettings()
    for _, bar in ipairs(self.bars) do self:ApplyBar(bar) end
end

function C:OnSettingChanged(node, key)
    local bar = node.barId and self.bars[node.barId]
    if bar then self:ApplyBar(bar) else self:ApplySettings() end
    if key == "enabled" then TK.EditMode:UpdateMovers() end
end
