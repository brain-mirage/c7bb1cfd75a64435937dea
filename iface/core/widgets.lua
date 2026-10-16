-- Shared widgets: panels, buttons, check boxes, sliders, drop-downs, edit boxes, headers and scroll areas, built only
-- from the frame API and procedural art. The settings window and the components use them.
--
-- s6-devtools (round 5; the interface separation's step 5: docs/development/interface-separation.md 5.15): each widget is
-- drawn with a skin, the colours and panel finish of whoever builds it. TK.UI's are the tools' skin (core/toolskin.lua);
-- an interface draws its own with TK.UI.With(its skin) (Modern's: interfaces/modern/skin.lua), whose constructors are
-- these same ones. The skin's colours are read as TK.UI.gold, TK.UI.panelEdge... (or the interface's set's).

local W = {}
TK.UI = W

local Tool = require("core.toolskin")

-- The constructors that draw with a skin, each taking it first (make.Label(S, parent, ...)); TK.UI's and TK.UI.With's
-- give it (bind).
local make = {}

--- A set of the widgets bound to skin S: set.Label(parent, ...) is make.Label(S, parent, ...), set.gold is S.gold; any
--- other name is fallback's (TK.UI's: what draws no skin, as the transparency, the menus and the prompts).
local function bind(set, S, fallback)
    return setmetatable(set, { __index = function(t, k)
        local m = make[k]
        if m then
            local f = function(...) return m(S, ...) end
            rawset(t, k, f)
            return f
        end
        local v = S[k]
        if v ~= nil then return v end
        return fallback and fallback[k]
    end })
end

-- TK.UI: the tools' widgets and colours
W.skin = Tool
bind(W, Tool)

--- The widgets drawn with an interface's own skin (a table of the tool skin's fields: core/toolskin.lua), and its colours
--- (set.gold, set.panelEdge...); set.skin is the skin.
function W.With(S) return bind({ skin = S }, S, W) end

-- s6-devtools (round 6; separation step 5): skinned action icons. The lookup defaults to TK.ActionIconInfo;
-- the held cursor uses the tools' skin in every interface (core/cursor.lua).
local ActionIcon = require("core.widgets.actionicon")
make.ActionIcon = ActionIcon.Draw
make.CursorIcon = ActionIcon.Cursor

local function color(fs, c) fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
W.Color = color

--- A plain label.
function make.Label(S, parent, text, size, c, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(size or 13, "")
    color(fs, c or S.white)
    if justify then fs:SetJustifyH(justify) end
    fs:SetText(text or "")
    return fs
end

-- s6-ui-core (round 57; s6-optimize's audit of round 51: the tooltip on hover was written three times, the settings
-- window's from s6-library round 18): GameTooltip's lines do not wrap, so a tip is cut into lines of about this many
-- characters.
local TIP_WIDTH = 60

--- A tooltip on a frame, shown while the pointer is over it: text (nil for none; a later call changes it), in lines of
--- about 60 characters. The owner: an explanation a player needs goes in a hover tooltip, not on the window.
function W.Tip(frame, text)
    frame.tipText = text
    if not text or frame.tipHooked then return frame end
    frame.tipHooked = true
    -- s6-ui-core (round 57; the live check: a dropdown's and a slider's tips never showed): the pointer's hover goes only
    -- to a frame that takes the mouse (UIHost.PointAt), and their own frames did not; their box, button or bar keeps its own
    frame:EnableMouse(true)
    frame:HookScript("OnEnter", function(self)
        if not self.tipText then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local line = ""
        for word in self.tipText:gmatch("%S+") do
            if line ~= "" and #line + 1 + #word > TIP_WIDTH then
                GameTooltip:AddLine(line, 1, 1, 1)
                line = word
            else
                line = line == "" and word or (line .. " " .. word)
            end
        end
        if line ~= "" then GameTooltip:AddLine(line, 1, 1, 1) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
    return frame
end

--- A bar of the player, party and target frames: the fill in its colour over a dark one (a fifth of it), and an
--- outlined value text in the middle (s6-optimize: was written three times). Modern's frames draw it with Modern's skin
--- (its set's VitalBar).
function make.VitalBar(S, parent, height, r, g, b, textSize, name)
    local s = CreateFrame("StatusBar", name, parent)
    s:SetHeight(height)
    s:SetStatusBarTexture("tk:bar")
    s:SetStatusBarColor(r, g, b, 1)
    local bg = s:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(s)
    bg:SetColorTexture(r * 0.2, g * 0.2, b * 0.2, 0.85)
    s.text = make.Label(S, s, "", textSize, S.white)
    s.text:SetFont(textSize, "OUTLINE")
    s.text:SetPoint("CENTER", s, "CENTER", 0, 0)
    return s
end

-- ----- the UI transparency: s6-ui-settings (round 4), s6-ui-core (round 53) -----
-- The owner (2026-10-05): "The global transparency setting should be about 25% for all Modern panels. This should affect
-- everything: character panel, settings menu etc." (until then the character page, the dialog boxes and the look window
-- stayed opaque). Every Modern panel's backdrop background is drawn at W.PanelAlpha: the Interface page's UI
-- Transparency (per profile, 25 %), or the panel's own where its settings untick "Use Global Transparency"
-- (TK.PanelTransparencyArgs). A window (an outer W.Panel on UIParent: every W.Window, the character, settings, look and
-- dialog windows) follows it from its making; a HUD panel made otherwise is marked with W.HudPanel. The panels inside a
-- window, the login screen's, the menus and the tooltips keep their own. Other art that follows it (the action bars'
-- slot backgrounds) reads W.PanelAlpha and redraws on TK_PANEL_STYLE_CHANGED. s6-ui-core (round 55): outside the world
-- (the login screen, New Character) every window is solid, and so is a popup (W.PopupPanel), anywhere (W.FramePanelAlpha).
-- s6-devtools (round 5; s6-optimize's audit of round 53, items 1 and 4): the see-through finish is a skin's (its
-- seeThrough: the tools' and Modern's have it, an original-client skin does not), so a window follows it by what draws it,
-- whatever interface is shown; and a marked panel carries its finish (frame.__finish), which the engine's
-- Frame:SetBackdropColor asks, so the engine knows no skin's finish.
-- s6-ui-core (round 56; s6-optimize's audit): the default, in percent, which the UI Transparency and every panel's own
-- slider start at (components/interface/settings.lua, TK.PanelTransparencyDefaults)
W.defaultTransparency = 25
local transparency = W.defaultTransparency / 100
local hudPanels = setmetatable({}, { __mode = "k" })

--- A panel's background opacity: 1 less its own transparency (0-1), or less the UI transparency without one.
function W.PanelAlpha(own) return 1 - (own or transparency) end

--- A panel's own transparency from its settings (TK.PanelTransparencyArgs' keys): 0-1, or nil while it uses the UI's.
function W.OwnTransparency(db)
    if db and db.useGlobalTransparency == false then return (db.transparency or W.defaultTransparency) / 100 end
    return nil
end

local function redraw(f)
    local c = f.__bgColor
    if c then f:SetBackdropColor(c[1], c[2], c[3], c[4]) end
end

-- The finishes Frame:SetBackdropColor asks (frame.__finish(frame, a): the opacity the background is drawn at). A window's:
-- the UI transparency's, or its own setting's, in place of its own; a background set clear stays clear (the aethers'
-- panel with no rows). An inner panel's: no fill while its window is see-through (W.InnerPanel).
local function windowFinish(f, a) if a > 0 then return W.FramePanelAlpha(f) end return a end
local function innerFinish(f, a) if W.InSeeThroughWindow(f) then return 0 end return a end

--- Marks a frame as a panel whose backdrop's background follows the UI transparency from now on. settings (optional):
--- where the panel may have its own (TK.PanelTransparencyArgs' keys): a component (its settings table), or a function
--- giving the table (a component's sub-table, as the aether list's).
function W.HudPanel(frame, settings)
    frame.__hud = true
    frame.__finish = windowFinish
    frame.__transparencyOf = settings
    hudPanels[frame] = true
    redraw(frame)
    return frame
end

--- The opacity a marked panel's background is drawn at (Frame:SetBackdropColor). s6-ui-core (round 55; the head's notes:
--- at the login screen the settings window and the login form showed through each other, and the shared Yes/No dialog
--- showed the window under it): solid at the login screen (New Character's too) and for a popup (W.PopupPanel), so their
--- text reads over what is under them; in the world the UI transparency, or the panel's own.
function W.FramePanelAlpha(frame)
    if frame.__popup or not TK.GameState:InWorld() then return 1 end
    local s = frame.__transparencyOf
    local db = type(s) == "function" and s() or (s and s:DB())
    return W.PanelAlpha(W.OwnTransparency(db))
end

--- s6-ui-core (round 53; Astra's review: the settings window's page, a panel in a panel, stayed nearly opaque): a panel
--- inside a window (W.Panel's inner one) draws its fill only while its window is opaque; in a see-through window only
--- its edge shows, so the whole window is as see-through as its setting.
function W.InnerPanel(frame)
    frame.__finish = innerFinish
    hudPanels[frame] = true
    redraw(frame)
    return frame
end

--- Whether the window a panel is inside (its nearest marked parent) is drawn see-through now.
function W.InSeeThroughWindow(frame)
    local p = frame:GetParent()
    while p and not p.__hud do p = p:GetParent() end
    return p ~= nil and W.FramePanelAlpha(p) < 1
end

-- s6-interface-5x (round 13, the separation's step 11): the frames of a panel turned off, destroyed, are not drawn again
TK.OnWithdraw(function()
    for f in pairs(hudPanels) do
        if TK.IsDead(f) then hudPanels[f] = nil end
    end
end)

--- Every panel's background drawn again, and TK_PANEL_STYLE_CHANGED (the UI's opacity) for the art that follows it.
function W.RedrawPanels()
    for f in pairs(hudPanels) do redraw(f) end
    TK.FireEvent("TK_PANEL_STYLE_CHANGED", W.PanelAlpha())
end

--- The Interface page's UI Transparency, 0 to 1 (its ApplySettings: at the start, on each change and on a profile
--- switch, which may change the panels' own too, so every panel is drawn again).
function W.SetUITransparency(t)
    transparency = t
    W.RedrawPanels()
end

--- s6-ui-core (round 55; the head's note, until the owner answers the pending question on Alpha and background
--- transparency): a popup, a question or a notice over other windows (W.Confirm, TK.Popup), is drawn solid whatever the
--- UI transparency (W.FramePanelAlpha).
function W.PopupPanel(frame)
    frame.__popup = true
    redraw(frame)
    return frame
end

-- s6-ui-core (round 55): the login screen's windows are solid and the world's follow the UI transparency, so every panel
-- is drawn again as the game goes between them
TK.On("TK_GAME_STATE", function() W.RedrawPanels() end)

--- A panel with the skin's background and bevelled edge (the tools' and Modern's: a charcoal shaded lighter at the top,
--- for a panel or window, and a darker recess for an inner one).
function make.Panel(S, parent, name, inner)
    local f = CreateFrame("Frame", name, parent)
    f:SetBackdrop({ bg = inner and S.innerBg or S.panelBg, edge = inner and S.innerEdge or S.panelEdge,
                    bgFile = S.panelFill })
    -- s6-ui-core (round 53): a window on the screen follows the UI transparency, and an inner panel its window;
    -- s6-devtools (round 5): with a skin that has the see-through finish
    if not S.seeThrough then return f end
    if inner then W.InnerPanel(f) elseif parent == UIParent then W.HudPanel(f) end
    return f
end

--- s6-ui-core (round 49; Astra's item 3): a window's backdrop with a shallow band of light behind its title, fading into
--- the panel (W.Window's, and the Character window's own title). It follows a see-through panel's opacity.
function make.TitleBand(S, f)
    f:SetBackdrop({ bg = S.panelBg, edge = S.panelEdge, bgFile = S.panelFill, band = S.titleBand })
end

--- A push button. style: "red" (Bartender's Key Bindings and Close), "grey" (default) or "flat".
function make.Button(S, parent, text, width, height, style, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 100, height or 22)
    local normal = b:CreateTexture(nil, "BACKGROUND")
    normal:SetAllPoints(b)
    normal:SetTexture("tk:button")
    -- s6-ui-core (round 49; Astra's item 6): the grey button and its caption a little softer (a warm gold), so the captions
    -- don't compete with the window titles; the red buttons keep theirs.
    local base = style == "red" and S.red or S.buttonGrey
    local caption = style == "red" and S.gold or S.buttonText
    normal:SetVertexColor(base[1], base[2], base[3], base[4])
    b:SetNormalTexture(normal)
    local pushed = b:CreateTexture(nil, "BACKGROUND")
    pushed:SetAllPoints(b)
    pushed:SetTexture("tk:button")
    pushed:SetVertexColor(base[1] * 0.7, base[2] * 0.7, base[3] * 0.7, 1)
    b:SetPushedTexture(pushed)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture("tk:button-hl")
    hl:SetVertexColor(1, 0.85, 0.4, 0.45)
    b:SetHighlightTexture(hl)
    local fs = b:GetFontString()
    fs:SetFont(13, "")
    b:SetNormalFontColor(caption[1], caption[2], caption[3], 1)
    b:SetText(text or "")
    --- s6-ui-core (round 63): a persistent selection for one-of groups; ordinary buttons keep their usual look.
    function b:SetSelected(on)
        self.selected = on and true or false
        local c = on and S.tabChosenBg or base
        normal:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        c = on and S.white or caption
        self:SetNormalFontColor(c[1], c[2], c[3], 1)
    end
    if onClick then b:SetScript("OnClick", onClick) end
    -- s6-audio hook: the interface click sound (the original's effect 408) on every standard button.
    -- s6-interface-7x (round 2): but a button with b.noClickSound set, drawn as one of 4a's dialog controls, which play
    -- no sound (ui/ControlPane.cpp plays none; a dialog's only sound is its opening's, DialogPane::AddToLayer).
    b:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and self:IsEnabled() and not self.noClickSound and TK.Game.Sound then TK.Game.Sound.PlayClick() end
    end)
    return b
end

--- s6-ui-core (round 63; the owner's one-of control): a group owns its members' clicks and always selects one.
--- Add(buttonOrCheck, value) accepts an existing control;
--- SetValue changes the selection silently, a click reports it. Configure builds a row of standard buttons from
--- { value, text, desc, disabled } choices. Declared settings needs use the group's title and SetGreyed, keeping its value.
function make.OneOf(S, parent, label, width, onChange)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 260, 48)
    f.title = make.Label(S, f, label or "", 13, S.gold, "LEFT")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.items, f.buttons, f.onChange = {}, {}, onChange
    function f:SetValue(value)
        local found = false
        for _, item in ipairs(self.items) do if item.value == value then found = true end end
        self.value = found and value or (self.items[1] and self.items[1].value)
        for _, item in ipairs(self.items) do
            local b, on = item.control, item.value == self.value
            if b.SetChecked then b:SetChecked(on) else b:SetSelected(on) end
        end
    end
    function f:GetValue() return self.value end
    function f:Add(control, value)
        local item = { control = control, value = value }
        self.items[#self.items + 1] = item
        control:SetScript("OnClick", function()
            local changed = self.value ~= item.value
            self:SetValue(item.value) -- clicking the selected check cannot leave the group empty
            if changed and self.onChange then self.onChange(item.value) end
        end)
        self:SetValue(self.value)
        return control
    end
    function f:SetEnabled(on)
        self.enabled = on
        for _, item in ipairs(self.items) do item.control:SetEnabled(on and not item.disabled) end
    end
    function f:SetGreyed(on)
        self:SetAlpha(on and 0.62 or 1)
    end
    function f:Configure(label2, choices, onChange2)
        self.title:SetText(label2)
        self.onChange, self.items = onChange2, {}
        local w = (self:GetWidth() - math.max(0, #choices - 1) * 6) / math.max(1, #choices)
        for i, choice in ipairs(choices) do
            local b = self.buttons[i] or make.Button(S, self, "", w, 24)
            self.buttons[i] = b
            b:SetText(choice.text)
            b:SetWidth(w)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * (w + 6), -20)
            W.Tip(b, choice.desc)
            self:Add(b, choice.value)
            self.items[i].disabled = choice.disabled
            b:Show()
        end
        for i = #choices + 1, #self.buttons do self.buttons[i]:Hide() end
        self:SetEnabled(true)
    end
    return f
end

--- s6-ui-core (round 61; the owner's reusable controls, s6-optimize's plan step 4: tabs were built by hand in eight
--- places): a tab, as the settings window's: the tab picture, dark with gold text, the chosen one lighter with white text
--- (tab:SetSelected), a gold light under the pointer, the standard buttons' click sound. Made as make.Button is; opts:
--- name (a global name, for the gate and the tests), size (the text's, 12), icon (a square side tab showing that picture
--- in place of text, in the slot's edge, gold when chosen: the character window's), look (its own colours,
--- { bg, chosenBg, text, chosenText }: the chat's see-through tabs).
function make.Tab(S, parent, text, width, height, onClick, opts)
    opts = opts or {}
    local look = opts.look or { bg = S.tabBg, chosenBg = S.tabChosenBg, text = S.gold, chosenText = S.white }
    local b = CreateFrame("Button", opts.name, parent)
    b:SetSize(width or 100, height or 24)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetTexture("tk:tab")
    b:SetNormalTexture(b.bg)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture("tk:button-hl")
    hl:SetVertexColor(1, 0.85, 0.4, 0.35)
    b:SetHighlightTexture(hl)
    if opts.icon then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -8)
        b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 8)
        b.icon:SetTexture(opts.icon)
        b.edge = b:CreateTexture(nil, "OVERLAY")
        b.edge:SetAllPoints(b)
        b.edge:SetTexture("tk:slot-border")
    end
    b:GetFontString():SetFont(opts.size or 12, "")
    b:SetText(text or "")
    --- Draws it as the chosen tab or not.
    function b:SetSelected(on)
        self.selected = on and true or false
        local bg, c = on and look.chosenBg or look.bg, on and look.chosenText or look.text
        self.bg:SetVertexColor(bg[1], bg[2], bg[3], bg[4] or 1)
        self:SetNormalFontColor(c[1], c[2], c[3], 1)
        if self.edge then self.edge:SetVertexColor(on and 1 or 0.55, on and 0.82 or 0.55, on and 0.3 or 0.58, 1) end
    end
    b:SetSelected(false)
    if onClick then b:SetScript("OnClick", onClick) end
    -- s6-ui-core (round 65): use the standard button's game sound route, which keeps volume and mute semantics.
    -- Sound belongs to an enabled user press; SetSelected and other programmatic refreshes stay silent.
    b:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and self:IsEnabled() and not self.noClickSound and TK.Game.Sound then TK.Game.Sound.PlayClick() end
    end)
    return b
end

--- s6-ui-core (round 62; s6-optimize's plan step 4: steppers were built by hand in five places): a stepper, "Label [<]
--- value [>]", a row 22 high. onStep(-1) on [<], onStep(1) on [>] (standard buttons: the click sound). label (nil for
--- none) in gold at the row's left, the [<] at labelWidth (56 with a label). The value (row.value, row:SetValue) sits
--- between the arrows: valueWidth wide (the row as wide as its parts), or without one filling the row between [<] at its
--- left and [>] at its right end (the caller sizes the row). opts: name (a global name), labelWidth, valueWidth, size (the
--- text's, 12), colour (the value's, white). Its parts: row.label, row.back, row.value, row.forward.
function make.Stepper(S, parent, label, onStep, opts)
    opts = opts or {}
    local size = opts.size or 12
    local row = CreateFrame("Frame", opts.name, parent)
    row:SetHeight(22)
    local labelW = label and (opts.labelWidth or 56) or 0
    if label then
        row.label = make.Label(S, row, label, size, S.gold, "LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    end
    row.back = make.Button(S, row, "<", 26, 20, nil, function() onStep(-1) end)
    row.back:SetPoint("LEFT", row, "LEFT", labelW, 0)
    row.value = make.Label(S, row, "", size, opts.colour or S.white)
    row.forward = make.Button(S, row, ">", 26, 20, nil, function() onStep(1) end)
    row.value:SetPoint("LEFT", row.back, "RIGHT", 2, 0)
    if opts.valueWidth then
        row.value:SetWidth(opts.valueWidth)
        row.forward:SetPoint("LEFT", row.value, "RIGHT", 2, 0)
        row:SetWidth(labelW + 26 + 2 + opts.valueWidth + 2 + 26)
    else
        row.forward:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.value:SetPoint("RIGHT", row.forward, "LEFT", -2, 0)
    end
    function row:SetValue(text) self.value:SetText(text) end
    return row
end

--- s6-ui-core (round 62; s6-optimize's plan step 4: the icon slot was drawn by hand in 13 places): the slot's picture,
--- drawn on frame: its box (tk:slot) in the skin's slot colour, an icon texture over it, its edge (tk:slot-border) and, on
--- a button, the light under the pointer. Only the picture: what the slot does (clicks, drags, tooltips) stays its
--- caller's. opts:
---   box: the part of frame it covers (default frame; the macro cell's box over its name);
---   bg: the box's colour (default S.slotBg);
---   edge: the edge's colour (default S.slotEdge, an item's; S.slotActionEdge an action button's; S.gold a chosen mark),
---     false for none;
---   light: the light's colour (default white at 0.4 on a button), false for none;
---   inset: the icon's inset from each side (default none: the caller places it, as TK.Art.Place does).
--- Returns the textures: bg, icon, edge, light (nil those left out).
function make.SlotArt(S, frame, opts)
    opts = opts or {}
    local box = opts.box or frame
    local function texture(layer, key, c)
        local t = frame:CreateTexture(nil, layer)
        t:SetAllPoints(box)
        t:SetTexture(key)
        t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        return t
    end
    local bg = texture("BACKGROUND", "tk:slot", opts.bg or S.slotBg)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    if opts.inset then
        icon:SetPoint("TOPLEFT", box, "TOPLEFT", opts.inset, -opts.inset)
        icon:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -opts.inset, opts.inset)
    end
    local edge = opts.edge ~= false and texture("OVERLAY", "tk:slot-border", opts.edge or S.slotEdge) or nil
    local light
    if opts.light ~= false and frame.SetHighlightTexture then
        light = texture("HIGHLIGHT", "tk:button-hl", opts.light or { 1, 1, 1, 0.4 })
        frame:SetHighlightTexture(light)
    end
    return bg, icon, edge, light
end

--- A small square button with a glyph texture (close, arrows).
function W.IconButton(parent, key, size, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 18, size or 18)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(b)
    t:SetTexture(key)
    t:SetVertexColor(0.85, 0.85, 0.85, 1)
    b.icon = t
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture("tk:glow")
    hl:SetVertexColor(1, 0.9, 0.5, 0.5)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

--- A check box with its label; the label is part of the clickable area.
--- onChange(checked) runs on a user click.
function make.Check(S, parent, label, onChange)
    local b = CreateFrame("CheckButton", nil, parent)
    local box = b:CreateTexture(nil, "ARTWORK")
    box:SetSize(22, 22)
    box:SetPoint("LEFT", b, "LEFT", 0, 0)
    box:SetTexture("tk:checkbox")
    b.box = box
    local check = b:CreateTexture(nil, "OVERLAY")
    check:SetSize(22, 22)
    check:SetPoint("LEFT", b, "LEFT", 1, 1)
    check:SetTexture("tk:check")
    b:SetCheckedTexture(check)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(22, 22)
    hl:SetPoint("LEFT", b, "LEFT", 0, 0)
    hl:SetTexture("tk:glow")
    hl:SetVertexColor(1, 0.9, 0.5, 0.35)
    local fs = make.Label(S, b, label, 13, S.white, "LEFT")
    fs:SetPoint("LEFT", box, "RIGHT", 6, 0)
    b.label = fs
    b.check, b.hl = check, hl -- s6-modular-g (round 12): a look may draw its own pictures (7.x's ONOFFBUT, RBUTTON)
    b.onChange = onChange
    b:SetSize(28 + fs:GetStringWidth(), 24)
    b:SetScript("OnClick", function(self)
        if self.onChange then self.onChange(self:GetChecked()) end
    end)
    function b:SetLabel(text)
        fs:SetText(text)
        self:SetSize(28 + fs:GetStringWidth(), 24)
    end
    function b:SetLabelEnabled(on)
        color(fs, on and S.white or S.grey)
        box:SetVertexColor(on and 1 or 0.5, on and 1 or 0.5, on and 1 or 0.5, 1)
        if on then self:Enable() else self:Disable() end
    end
    return b
end

local function formatValue(v, step)
    if step and step >= 1 then return tostring(math.floor(v + 0.5)) end
    local s = string.format("%.2f", v)
    s = s:gsub("0+$", ""):gsub("%.$", "")
    return s
end

--- s6-ui-core (round 57; s6-optimize, through s6-effects: W.RangeSlider's box copied W.Slider's): a slider's value box,
--- an edit box under its track. Enter gives its number, if it is one, to set(v); then Enter and Escape both show the
--- slider's value again (show(box)) and let the box go.
local function valueBox(parent, width, set, show)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, 17)
    box:SetBackdrop({ bg = { 0, 0, 0, 0.55 }, edge = { 0.3, 0.3, 0.3, 1 }, bgFile = "tk:white", edgeFile = "tk:edge" })
    box:SetFontSize(11)
    box:SetJustifyH("CENTER")
    box:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then set(v) end
        show(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        show(self)
        self:ClearFocus()
    end)
    return box
end

--- s6-ui-core (round 60; the owner, 2026-10-06: "instead of a single slider bar and a seperate dual slider bar we have a
--- single one where you can enable multiple sliders, you can toggle the sliders on and off, it can push others"): the
--- one slider, laid out like Bartender's: the name above (its tooltip, W.Tip, on the frame), the track, and under it the
--- values. It replaces round 11's two-handle W.RangeSlider (s6-effects) and the engine's one-thumb Slider, drawn with that
--- Slider's track and thumb, so a one-handle slider looks as before: the minimum and maximum under the track's ends and
--- its value box under the middle. With more handles each has a value box, spread under the track, and the range between
--- the first and last is lit. Each handle is one value. A handle drags with the mouse, and a press on the track brings the
--- nearest one there; a typed number and Enter set it too. onChange(v1, v2, ...) runs when the user changes them.
---
--- opts (all optional, Configure takes them again): handles = { {}, { relative = 1, toggle = "Fade Out" }, ... }, one
--- table a handle (one handle when left out): relative, a handle's index its value is shown from ("+150", and a number
--- typed in its box counts from there too); toggle, the label of a check box under the track that turns the handle on and
--- off (a handle that is off is not drawn and pushes nothing; onToggle(i, on) hears the box). gap: the least distance
--- between neighbouring handles, in whole steps (rounded up); one moved into the next pushes it, and stops where the ones
--- it pushes reach an end.
--- stop = { text = "Off", value = 0 }: an end stop past the maximum, labelled text, where a handle's value is value (and
--- the handles after it go there too).
--- s6-ui-core (round 62; the owner's View Distance row, the head's note view-distance-row): a handle's toggleTip, its
--- check box's tooltip; togglesBeside, the check boxes right of the track (one under another) instead of under it;
--- stop.onlyWithout = i, the stop there only while handle i is off (turned on, a handle at the stop goes to the maximum).
--- s6-ui-core (round 63; the owner's mock-up): sections = N or { { text, desc }, ... } uses N evenly spaced stops
--- numbered 1–N, snaps through the same drag path, draws dividers and shows each divider's or handle's detailed tooltip.
--- In sectioned mode, releasing a click on an unchanged stop also reports once, so its preset can be reapplied.
local SLIDER_INSET, STOP_W = 6, 30 -- the thumb's centre stays 6 in from each end, as the engine Slider's; the stop's room
local AT_STOP = math.huge          -- a handle at the end stop, inside the control

function make.Slider(S, parent, label, min, max, step, width, onChange, opts)
    local f = CreateFrame("Frame", nil, parent)
    width = width or 180
    f:SetSize(width, 50)
    local title = make.Label(S, f, label, 13, S.gold)
    -- the track (f.slider, where the old Slider was: tests press it and ask it IsEnabled); its right end is Configure's
    local track = CreateFrame("Button", nil, f)
    track:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -17)
    track:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -17)
    track:SetHeight(18)
    title:SetPoint("TOP", track, "TOP", 0, 17) -- over the track (round 62: check boxes may be beside it)
    local bar = track:CreateTexture(nil, "BACKGROUND")
    bar:SetTexture("tk:slider-track")
    bar:SetPoint("LEFT", track, "LEFT", 0, 0)
    bar:SetPoint("RIGHT", track, "RIGHT", 0, 0)
    bar:SetHeight(8)
    local lit = track:CreateTexture(nil, "ARTWORK")
    lit:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.6)
    lit:SetHeight(8)
    local stopWell = track:CreateTexture(nil, "ARTWORK") -- the end stop's part of the track, darker
    stopWell:SetColorTexture(0, 0, 0, 0.45)
    stopWell:SetHeight(8)
    local lo = make.Label(S, f, "", 10, S.white)
    lo:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 2, -1)
    local hi = make.Label(S, f, "", 10, S.white)
    local stopLabel = make.Label(S, f, "", 10, S.white)
    stopLabel:SetPoint("TOPRIGHT", track, "BOTTOMRIGHT", -2, -1)
    f.slider, f.title, f.lo, f.hi = track, title, lo, hi
    local vals, shown, thumbs, boxes, toggles = {}, {}, {}, {}, {}
    local dividers = {}
    f.dividers, f.thumbs = dividers, thumbs
    f.sectionLabel = make.Label(S, f, "", 12, S.white)
    f.sectionLabel:SetPoint("TOP", track, "BOTTOM", 0, -16)
    f.boxes, f.toggles = boxes, toggles
    local enabled, n = true, 0
    local besideW, laidStop = 0, nil -- round 62: the check boxes' room right of the track; the stop the layout has

    local function trackW() return f:GetWidth() - besideW end
    -- round 62: the stop, unless the handle it goes with (stop.onlyWithout) is on
    local function hasStop() return f.stop ~= nil and not (f.stop.onlyWithout and shown[f.stop.onlyWithout]) end
    local function inset() return f.originalControl and 19.5 or SLIDER_INSET end
    local function span() return math.max(1, trackW() - 2 * inset() - (hasStop() and STOP_W or 0)) end
    local function x(v)
        if v == AT_STOP then return trackW() - SLIDER_INSET end
        local offset = (v - f.min) / math.max(1e-9, f.max - f.min) * span()
        return inset() + (f.originalControl and math.floor(offset) or offset)
    end
    local function snap(v)
        v = TK.Util.Clamp(v, f.min, f.max)
        if f.step and f.step > 0 then v = math.min(f.max, f.min + TK.Util.Round(v - f.min, f.step)) end
        v = math.floor(v * 1e6 + 0.5) / 1e6 -- no floating noise such as 0.30000000000000004 (the engine Slider's rule)
        return math.tointeger(v) or v       -- a whole number as one (shown and stored "40", not "40.0")
    end
    -- the value under the pointer (the stop past the maximum's half of its room)
    local function pointed()
        local l, _, w = TK.Util.RootRect(track)
        local px = (TK.Util.CursorRoot() - l) / math.max(1e-9, w) * trackW()
        if hasStop() and px > SLIDER_INSET + span() + STOP_W / 2 then return AT_STOP end
        local value = f.min + (px - (f.dragOffset or 0) - inset()) / span() * (f.max - f.min)
        -- Original SetValueFromThumbDrag 0x00497D80 uses integer division; other slider modes keep rounding.
        return snap(f.originalControl and math.floor(value) or value)
    end
    -- r66: the existing slider can take original music-control input without a second slider. Geometry is
    -- SliderControlPane::GetPartRect: 13px caps/thumb; keys and repeat timing remain the model's.
    function f:OriginalPointer()
        local l, b, w, h = TK.Util.RootRect(track)
        local cx, cy = TK.Util.CursorRoot()
        return (cx - l) / math.max(1e-9, w) * trackW(), trackW(), cy >= b and cy < b + h
    end
    function f:OriginalPart()
        local px, width, inside = self:OriginalPointer()
        local left = x(vals[1]) - 6.5
        if not inside or px < 0 or px >= width then return 10 end
        if px < 13 then return 13 end
        if px >= trackW() - 13 then return 17 end
        if px < left then return 14 end
        if px >= left + 13 then return 16 end
        return 15
    end
    local put
    local function originalPress()
        f.activePart = f:OriginalPart()
        if f.activePart == 15 then
            local l, _, w = TK.Util.RootRect(track)
            f.dragOffset = (TK.Util.CursorRoot() - l) / math.max(1e-9, w) * trackW() - x(vals[1])
            f.dragging = 1
            put(1, pointed(), true) -- snapshot the initial integer thumb target before the physical press reaches K.Wire
        else
            local step = ({ [13] = -1, [14] = -10, [16] = 10, [17] = 1 })[f.activePart] or 0
            put(1, vals[1] + step, true)
        end
    end
    local function reported(v) return v == AT_STOP and f.stop.value or v end
    local function text(i)
        local v, r = vals[i], f.handles[i].relative
        if f.sections then return f.sections[v].text or tostring(v) end
        if v == AT_STOP then return f.stop.text end
        if r and shown[r] and vals[r] ~= AT_STOP then
            local d = v - vals[r]
            return (d >= 0 and "+" or "-") .. formatValue(math.abs(d), f.step)
        end
        return formatValue(v, f.step)
    end

    -- What moves with the stop: the maximum's label before it, the stop's label and well, and with more handles the value
    -- boxes, spread under the track, the last at the maximum's end.
    local function layout()
        laidStop = hasStop()
        local room = laidStop and STOP_W or 0
        hi:ClearAllPoints()
        hi:SetPoint("TOPRIGHT", track, "BOTTOMRIGHT", -2 - room, -1)
        stopLabel:SetText(laidStop and f.stop.text or "")
        stopWell:SetShown(laidStop)
        for i = 1, n do
            local b = boxes[i]
            b:ClearAllPoints()
            if n == 1 then
                b:SetPoint("TOP", track, "BOTTOM", 0, -1)
            else
                b:SetPoint("TOPLEFT", track, "BOTTOMLEFT", math.floor((trackW() - room - 52) * (i - 1) / (n - 1)), -1)
            end
        end
    end

    local function show()
        if hasStop() ~= laidStop then layout() end
        local first, last
        for i = 1, n do
            local t, b = thumbs[i], boxes[i]
            t:SetShown(shown[i])
            b:SetShown(shown[i] and not f.sections)
            if shown[i] then
                t:ClearAllPoints()
                t:SetPoint("CENTER", track, "LEFT", x(vals[i]), 0)
                if not b:HasFocus() then b:SetText(text(i)) end
                if f.sections then
                    local section = f.sections[vals[i]]
                    t.tipText = (section.text or tostring(vals[i])) .. ". " .. (section.desc or "")
                else t.tipText = nil end
                first, last = first or i, i
            end
        end
        f.sectionLabel:SetShown(f.sections ~= nil)
        if f.sections then f.sectionLabel:SetText(text(1)) end
        lit:ClearAllPoints()
        lit:SetShown(n > 1 and first ~= nil and first ~= last)
        if first then
            lit:SetPoint("LEFT", track, "LEFT", x(vals[first]), 0)
            lit:SetWidth(math.max(1, x(vals[last]) - x(vals[first])))
        end
    end

    -- The shown handles in order, and where handle i is among them.
    local function order(i)
        local o, k = {}, nil
        for j = 1, n do
            if shown[j] then
                o[#o + 1] = j
                if j == i then k = #o end
            end
        end
        return o, k
    end

    -- The gap in whole steps (rounded up: 10 with a step of 8 is 16), so a pushed handle stays on the step's grid
    -- (Astra's r60-2 review: else showing the values again snapped the gap smaller).
    local function gap()
        local g = f.gap or 0
        if g > 0 and f.step and f.step > 0 then g = math.ceil(g / f.step - 1e-9) * f.step end
        return g
    end

    --- Puts handle i at v (a number or AT_STOP), held where the handles it pushes still fit, and pushes them by the gap.
    --- Reports the values when one changed (user: the user's change).
    put = function(i, v, user, before)
        before = before or { table.unpack(vals, 1, n) }
        local o, k = order(i)
        local g = gap()
        if v ~= AT_STOP then
            v = TK.Util.Clamp(snap(v), f.min + g * (k - 1), math.max(f.min + g * (k - 1), f.max - g * (#o - k)))
        end
        vals[i] = v
        for m = k + 1, #o do -- the ones after it, up (past the stop, still at the stop)
            local need = vals[o[m - 1]] + g
            if vals[o[m]] < need then vals[o[m]] = need == AT_STOP and need or snap(need) end
        end
        for m = k - 1, 1, -1 do -- the ones before it, down
            local most = vals[o[m + 1]] - g
            if vals[o[m]] > most then vals[o[m]] = snap(most) end
        end
        show()
        if not user or not f.onChange then return end
        for j = 1, n do
            if vals[j] ~= before[j] then
                f.reapply = nil
                return f.onChange(f:GetValue())
            end
        end
    end

    local function thumb(i)
        local t = CreateFrame("Button", nil, track)
        t:SetSize(12, 18)
        t.tex = t:CreateTexture(nil, "OVERLAY")
        t.tex:SetAllPoints(t)
        t.tex:SetTexture("tk:slider-thumb")
        t:SetScript("OnMouseDown", function(_, button)
            -- Section handles use the track's selection path, including a click that reapplies the current stop.
            if f.originalControl then return track:GetScript("OnMouseDown")(track, button) end
            if f.sections then return track:GetScript("OnMouseDown")(track, button) end
            if button == "LeftButton" and enabled then f.dragging = i end
        end)
        t:SetScript("OnMouseUp", function() f:Release(true) end)
        t:SetScript("OnPressCancelled", function() f:Release() end) -- round 61: the press let go with no release
        W.Tip(t, "") -- install the hook once; the selected section's detail is updated by show()
        return t
    end
    local function valueBoxFor(i)
        return valueBox(f, 64, function(v)
            local r = f.handles[i].relative -- a box shown from another handle counts from it (Astra's r60-2 review)
            if r and shown[r] and vals[r] ~= AT_STOP then v = vals[r] + v end
            put(i, v, true)
        end, function(b) b:SetText(text(i)) end)
    end

    -- a press on the track brings the nearest shown handle there (of two in one place, the one on the pointer's side), and
    -- it follows the pointer until released
    track:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or not enabled then return end
        if f.originalControl then originalPress() return end
        local v, best, dist = pointed(), nil, nil
        for i = 1, n do
            if shown[i] then
                local d = math.abs(x(v) - x(vals[i]))
                if not best or d < dist or d == dist and v > vals[i] then best, dist = i, d end
            end
        end
        if not best then return end
        f.dragging = best
        -- Wait for release before reapplying an unchanged section. A drag to another stop must not apply this one first.
        f.reapply = f.sections and true or nil
        put(best, v, true)
    end)
    track:SetScript("OnMouseUp", function() f:Release(true) end)
    -- s6-ui-core (round 61; Astra's review of round 60, P2): the window losing the focus lets the press go with no
    -- OnMouseUp (UIHost.FocusChanged), so the drag ends there too, not following the pointer after an Alt-Tab
    track:SetScript("OnPressCancelled", function() f:Release() end)
    f:SetScript("OnUpdate", function()
        if f.dragging then put(f.dragging, pointed(), true) end
    end)

    --- Ends or cancels a drag; a mouse release also reapplies a clicked, unchanged section once.
    function f:Release(apply)
        local reapply = apply and f.reapply
        f.dragging, f.reapply, f.dragOffset, f.activePart = nil, nil, nil, nil
        if reapply and f.onChange then f.onChange(f:GetValue()) end
    end

    --- The handles' values, in order (a handle at the end stop: the stop's value).
    function f:GetValue()
        local out = {}
        for i = 1, n do out[i] = reported(vals[i]) end
        return table.unpack(out, 1, n)
    end

    --- Shows the values (one a handle, in order); the stop's value puts a handle at the stop. Nothing is reported.
    function f:SetValue(...)
        for i = 1, n do
            local v = select(i, ...)
            if f.stop and v == f.stop.value then
                vals[i] = hasStop() and AT_STOP or f.max -- round 62: at the maximum while the stop is away
            else
                vals[i] = snap(tonumber(v) or f.min)
            end
        end
        show()
    end

    --- Turns handle i on or off (its check box too). user: the user's change; a handle turned on is then moved between its
    --- shown neighbours if it was not there, and the values reported.
    function f:SetHandleShown(i, on, user)
        local before = { table.unpack(vals, 1, n) }
        shown[i] = on and true or false
        if toggles[i] then toggles[i]:SetChecked(shown[i]) end
        if not hasStop() then -- round 62: the stop went with this handle on (stop.onlyWithout): its handles to the maximum
            for j = 1, n do
                if vals[j] == AT_STOP then vals[j] = f.max end
            end
        end
        if on and user then
            local o, k = order(i)
            local g = gap()
            local v = vals[i]
            if k > 1 then v = math.max(v, vals[o[k - 1]] + g) end
            if k < #o then v = math.min(v, vals[o[k + 1]] - g) end
            if v ~= AT_STOP and v > f.max then v = hasStop() and AT_STOP or f.max end
            return put(i, v, true, before)
        end
        show()
    end

    --- Sets the slider up for an option (the settings page reuses one for another).
    function f:Configure(label2, min2, max2, step2, onChange2, opts2)
        opts2 = opts2 or {}
        title:SetText(label2)
        f.min, f.max, f.step, f.onChange = min2, max2, step2, onChange2
        -- Sectioned mode uses evenly spaced indices on this same slider and its ordinary snapping/drag path.
        -- Pass a count or { { text, desc }, ... }; Configure also clears the mode on a pooled slider's next use.
        f.originalControl = opts2.originalControl == true
        track:SetHeight(f.originalControl and 13 or 18)
        f.sections = opts2.sections
        if type(f.sections) == "number" then
            local count = f.sections
            f.sections = {}
            for i = 1, count do f.sections[i] = { text = tostring(i) } end
        end
        if f.sections then f.min, f.max, f.step = 1, #f.sections, 1 end
        f.handles, f.gap, f.stop, f.onToggle = opts2.handles or { {} }, opts2.gap, opts2.stop, opts2.onToggle
        n = #f.handles
        local beside, toggleY = opts2.togglesBeside, 0
        besideW = 0
        for i = 1, n do
            thumbs[i] = thumbs[i] or thumb(i)
            thumbs[i]:SetSize(f.originalControl and 13 or 12, f.originalControl and 13 or 18)
            boxes[i] = boxes[i] or valueBoxFor(i)
            -- a reused slider starts from the new minimum, not the last option's values (Astra's r60-2 review: one left at
            -- an end stop broke a slider without one); its option's values come next (SetValue)
            vals[i], shown[i] = f.min, true
            boxes[i]:SetWidth(n == 1 and 64 or 52)
            local label3 = f.handles[i].toggle
            if label3 then
                local c = toggles[i] or make.Check(S, f, "")
                toggles[i] = c
                c:SetLabel(label3)
                W.Tip(c, f.handles[i].toggleTip) -- round 62 (nil clears a reused box's)
                c:ClearAllPoints()
                if beside then -- round 62: right of the track, level with it, one under another
                    c:SetPoint("LEFT", track, "RIGHT", 8, -toggleY)
                    besideW = math.max(besideW, c:GetWidth() + 8)
                else
                    c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -56 - toggleY)
                end
                c.onChange = function(on)
                    f:SetHandleShown(i, on, true)
                    if f.onToggle then f.onToggle(i, on) end
                end
                c:SetChecked(true)
                c:Show()
                toggleY = toggleY + 24
            elseif toggles[i] then
                toggles[i]:Hide()
            end
        end
        for i = n + 1, #thumbs do
            thumbs[i]:Hide()
            boxes[i]:Hide()
            if toggles[i] then toggles[i]:Hide() end
        end
        track:SetPoint("TOPRIGHT", f, "TOPRIGHT", -besideW, -17)
        -- one handle: the ends' values under the ends (the maximum's before the stop); more: the boxes say it
        lo:SetText(n == 1 and (f.sections and f.sections[1].text or formatValue(min2, step2)) or "")
        hi:SetText(n == 1 and (f.sections and f.sections[#f.sections].text or formatValue(max2, step2)) or "")
        stopWell:ClearAllPoints()
        stopWell:SetPoint("LEFT", track, "RIGHT", -STOP_W - SLIDER_INSET + 4, 0)
        stopWell:SetPoint("RIGHT", track, "RIGHT", 0, 0)
        f:SetHeight((f.sections and 66 or 50) + (beside and math.max(0, toggleY - 24) or toggleY))
        for i, section in ipairs(f.sections or {}) do
            local d = dividers[i]
            if not d then
                -- Track siblings draw above its bar but below its child handles; all levels follow the window.
                d = CreateFrame("Button", nil, f)
                d:SetSize(8, 18)
                local tick = d:CreateTexture(nil, "ARTWORK")
                tick:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.8)
                tick:SetSize(2, 12)
                tick:SetPoint("CENTER", d, "CENTER", 0, 0)
                -- Dividers share the track's press/release path, including focus cancellation.
                for _, event in ipairs({ "OnMouseDown", "OnMouseUp", "OnPressCancelled" }) do
                    d:SetScript(event, function(_, ...) track:GetScript(event)(track, ...) end)
                end
                dividers[i] = d
            end
            d:ClearAllPoints()
            d:SetPoint("CENTER", track, "LEFT", x(i), 0)
            W.Tip(d, (section.text or tostring(i)) .. ". " .. (section.desc or ""))
            d:Show()
        end
        for i = #(f.sections or {}) + 1, #dividers do dividers[i]:Hide() end
        layout()
        show()
    end

    function f:SetEnabled(on)
        enabled = on
        if not on then f.dragging = nil end
        if on then track:Enable() else track:Disable() end
        local c = on and S.white or S.grey
        for i = 1, n do
            boxes[i]:SetEnabled(on)
            thumbs[i].tex:SetVertexColor(on and 1 or 0.5, on and 1 or 0.5, on and 1 or 0.5, 1)
            if toggles[i] then toggles[i]:SetLabelEnabled(on) end
        end
        color(title, on and S.gold or S.grey)
        color(lo, c)
        color(hi, c)
        color(stopLabel, c)
        lit:SetAlpha(on and 1 or 0.3)
    end
    f:SetScript("OnSizeChanged", show)
    f:Configure(label, min, max, step, onChange, opts)
    f.box = boxes[1] -- a one-handle slider's value box
    f:SetValue(min)
    return f
end

local openDropdown

--- A drop-down: a label, a box with the current choice and an arrow, and a list that opens below it.
--- values is an array of { value = v, text = "..." }. onChange(value) runs when the user picks one.
function make.Dropdown(S, parent, label, values, width, onChange)
    local f = CreateFrame("Frame", nil, parent)
    width = width or 180
    f:SetSize(width, 44)
    local title = make.Label(S, f, label, 13, S.gold)
    title:SetPoint("TOP", f, "TOP", 0, 0)
    local b = CreateFrame("Button", nil, f)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -18)
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -18)
    b:SetHeight(22)
    b:SetBackdrop({ bg = S.fieldBg, edge = S.fieldEdge })   -- s6-ui-core (round 49): a charcoal well, not a black hole
    local text = make.Label(S, b, "", 12, S.white, "LEFT")
    text:SetPoint("LEFT", b, "LEFT", 8, 0)
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", b, "RIGHT", -5, 0)
    arrow:SetTexture("tk:arrow-down")
    arrow:SetVertexColor(1, 0.82, 0, 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture("tk:button-hl")
    hl:SetVertexColor(1, 0.85, 0.4, 0.3)
    f.values, f.button, f.text, f.title, f.onChange = values, b, text, title, onChange
    local current

    local list
    local function closeList()
        if list then list:Hide() end
        if openDropdown == f then openDropdown = nil end
    end
    f.CloseList = closeList

    local function openList()
        if openDropdown and openDropdown ~= f then openDropdown.CloseList() end
        if not list then
            list = CreateFrame("Frame", nil, UIParent)
            list:SetFrameStrata("FULLSCREEN_DIALOG")
            list:SetBackdrop({ bg = S.menuBg, edge = S.panelEdge, bgFile = "tk:white" })
            list:EnableMouse(true)
            -- s6-modular-g (round 21, the owner's research on presses reaching the wrong place; Astra's self-reviews 21-1
            -- and 21-2): the list is UIParent's, so it goes when its dropdown is no longer shown (its window hidden from
            -- code, which fires no OnHide on the dropdown); it stayed showing and took presses. Our own window.
            list:SetScript("OnUpdate", function() if not f:IsVisible() then closeList() end end)
            list.items = {}
            list.dropdown = f -- s6-input: a press on the list is the drop-down's window's (core/settings.lua's focus)
            f.list = list
        end
        for _, item in ipairs(list.items) do item:Hide() end
        for i, v in ipairs(f.values) do
            local item = list.items[i]
            if not item then
                item = CreateFrame("Button", nil, list)
                item:SetHeight(20)
                local ihl = item:CreateTexture(nil, "HIGHLIGHT")
                ihl:SetAllPoints(item)
                ihl:SetColorTexture(S.menuHighlight[1], S.menuHighlight[2], S.menuHighlight[3], S.menuHighlight[4])
                item.highlight = ihl -- callers can replace the hover light with their own menu selection
                item.label = make.Label(S, item, "", 12, S.white, "LEFT")
                item.label:SetPoint("LEFT", item, "LEFT", 22, 0)
                item.check = item:CreateTexture(nil, "OVERLAY")
                item.check:SetSize(14, 14)
                item.check:SetPoint("LEFT", item, "LEFT", 5, 0)
                item.check:SetTexture("tk:check")
                list.items[i] = item
            end
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4 - (i - 1) * 20)
            item:SetPoint("TOPRIGHT", list, "TOPRIGHT", -4, -4 - (i - 1) * 20)
            item.label:SetText(v.text)
            item.check:SetShown(v.value == current)
            item:SetScript("OnClick", function()
                closeList()
                f:SetValue(v.value)
                if f.onChange then f.onChange(v.value) end
            end)
            item:Show()
        end
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
        list:SetSize(math.max(width, 120), #f.values * 20 + 8)
        list:Show()
        openDropdown = f
    end
    -- A caller with its own keyboard input rules can show the same list without synthesizing a click.
    f.OpenList = openList

    b:SetScript("OnClick", function()
        if list and list:IsShown() then closeList() else openList() end
    end)

    function f:SetValue(v)
        current = v
        for _, x in ipairs(f.values) do
            if x.value == v then text:SetText(x.text) return end
        end
        text:SetText(tostring(v))
    end
    function f:GetValue() return current end
    function f:SetValues(vs) f.values = vs end
    --- Reuses the drop-down for another option.
    function f:Configure(label2, values2, onChange2)
        title:SetText(label2)
        f.values, f.onChange = values2, onChange2
        closeList()
    end
    function f:SetEnabled(on)
        if on then b:Enable() else b:Disable() end
        color(title, on and S.gold or S.grey)
        color(text, on and S.white or S.grey)
    end
    return f
end

--- Closes an open drop-down list; true if one was open (Escape uses this).
function W.CloseDropdowns()
    if openDropdown then
        openDropdown.CloseList()
        return true
    end
    return false
end

TK.On("GLOBAL_MOUSE_DOWN", function()
    if not openDropdown then return end
    -- Music MenuPane 0x00516940 owns consumption/close in the existing physical record. Its caller renders
    -- the model request; an eager close changes accepted input and what the server sees. Other callers stay generic.
    if openDropdown.modelMenu then return end
    -- A click anywhere but in the list or on its own button closes the list.
    local focus = GetMouseFocus()
    while focus do
        if focus == openDropdown.button then return end
        local p = focus:GetParent()
        if p and p.items then return end
        focus = p
    end
    openDropdown.CloseList()
end)

--- A single-line edit box with the standard look.
function make.EditBox(S, parent, width, height)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width or 160, height or 22)
    e:SetBackdrop({ bg = S.fieldBg, edge = S.fieldEdge })   -- s6-ui-core (round 49): a charcoal well, not a black hole
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

--- A centred gold header with a line on either side, as in Bartender's option groups.
function make.Header(S, parent, text, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 400, 20)
    local fs = make.Label(S, f, text, 13, S.gold)
    fs:SetPoint("CENTER", f, "CENTER", 0, 0)
    local left = f:CreateTexture(nil, "ARTWORK")
    left:SetHeight(1)
    left:SetPoint("LEFT", f, "LEFT", 0, 0)
    left:SetPoint("RIGHT", fs, "LEFT", -8, 0)
    left:SetColorTexture(S.headerRule[1], S.headerRule[2], S.headerRule[3], S.headerRule[4])
    local right = f:CreateTexture(nil, "ARTWORK")
    right:SetHeight(1)
    right:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    right:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    right:SetColorTexture(S.headerRule[1], S.headerRule[2], S.headerRule[3], S.headerRule[4])
    f.label = fs
    f.right = right -- s6-ui-core (round 60): the settings page starts it after a header's (!) (showNeeds)
    return f
end

--- A scrolling area: returns the scroll frame and its content frame (set the content's height).
--- The thin bar on the right shows the position and can be dragged.
function W.ScrollArea(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(10, 10)
    sf:SetScrollChild(content)
    local track = CreateFrame("Frame", nil, parent)
    track:SetWidth(6)
    track:SetPoint("TOPLEFT", sf, "TOPRIGHT", 2, 0)
    track:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 2, 0)
    local trackTex = track:CreateTexture(nil, "BACKGROUND")
    trackTex:SetAllPoints(track)
    trackTex:SetColorTexture(0.11, 0.115, 0.13, 1)   -- s6-ui-core (round 49): a dark track and a brass thumb
    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(6)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints(thumb)
    thumbTex:SetColorTexture(0.52, 0.47, 0.32, 1)
    thumb:RegisterForDrag("LeftButton")

    local function refresh()
        local range = sf:GetVerticalScrollRange()
        local h = sf:GetHeight()
        -- s6-modular-g (interfaces, phase 4): a look may draw the bar its own way (sf.barStyle(range, h): 7.x's lists,
        -- 4a's track and thumb); the bar's input stays this one's
        if sf.barStyle then return sf.barStyle(range, h) end
        track:SetShown(range > 0.5)
        if range <= 0.5 or h <= 0 then return end
        local total = h + range
        local th = math.max(20, h * h / total)
        thumb:SetHeight(th)
        local pos = sf:GetVerticalScroll() / range * (h - th)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -pos)
    end

    -- delta: the wheel's notches; wheelStep: pixels a notch (s6-rules-dialogs: a dialog's list scrolls one row).
    sf:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(self:GetVerticalScroll() - delta * (self.wheelStep or 40))
        refresh()
    end)

    local dragStart
    -- The thumb follows the cursor while dragged (s6-rules-dialogs: also called from a dialog list's move).
    local function dragStep()
        if not dragStart then return end
        local _, cy = TK.Util.CursorRoot()
        local range = sf:GetVerticalScrollRange()
        local h = sf:GetHeight()
        local th = thumb:GetHeight()
        if h - th <= 0 then return end
        sf:SetVerticalScroll(dragStart.scroll + (dragStart.y - cy) * range / (h - th))
        refresh()
    end
    thumb.DragStep = dragStep
    thumb:SetScript("OnDragStart", function()
        local _, y = TK.Util.CursorRoot()
        dragStart = { y = y, scroll = sf:GetVerticalScroll() }
        thumb:SetScript("OnUpdate", dragStep)
    end)
    thumb:SetScript("OnDragStop", function()
        thumb:SetScript("OnUpdate", nil)
        dragStart = nil
    end)

    sf.content, sf.Refresh = content, refresh
    sf.thumb = thumb -- s6-rules-dialogs: a dialog's list takes presses on its scroll bar
    sf.track, track.bg, thumb.tex = track, trackTex, thumbTex -- s6-modular-g: the bar's parts, for sf.barStyle
    function sf:ScrollToTop()
        self:SetVerticalScroll(0)
        refresh()
    end
    return sf, content
end

-- ----- the error line at the top of the screen (WoW's UIErrorsFrame) -----

local errors = CreateFrame("Frame", "UIErrorsFrame", UIParent)
errors:SetSize(600, 60)
errors:SetPoint("TOP", UIParent, "TOP", 0, -110)
errors:SetFrameStrata("DIALOG")
errors.lines = {}
for i = 1, 3 do
    local fs = W.Label(errors, "", 16, { 1, 0.1, 0.1 })
    fs:SetFont(16, "OUTLINE")
    fs:SetPoint("TOP", errors, "TOP", 0, -(i - 1) * 20)
    fs:Hide()
    errors.lines[i] = { fs = fs, age = 0 }
end

--- Line a takes line p's message. s6-ui-core (build 41): with its colour (a yellow notice went red on the second line),
--- its fade (a line faded before kept its old alpha) and its key.
local function moveLine(a, p)
    a.fs:SetText(p.fs:GetText())
    a.age, a.colour, a.key = p.age, p.colour, p.key
    if a.colour then a.fs:SetTextColor(a.colour[1], a.colour[2], a.colour[3], 1) end
    a.fs:SetAlpha(a.age > 2 and 3 - a.age or 1)
    a.fs:SetShown(p.fs:IsShown())
end

--- s6-ui-core (build 41): key (optional) names a kind of message; a new one takes the place of the shown one of its kind,
--- so the Cycle Graphics Style's "Mode: ..." lines never stack up, the newest on top.
function errors:AddMessage(text, r, g, b, key)
    local lines = self.lines
    if key then
        for j, l in ipairs(lines) do
            if l.fs:IsShown() and l.key == key then
                for i = j, #lines - 1 do moveLine(lines[i], lines[i + 1]) end
                lines[#lines].fs:Hide()
                lines[#lines].key = nil
                break
            end
        end
    end
    -- Newest on top; the same message (of the same kind) again only refreshes its time, and its fade.
    for _, l in ipairs(lines) do
        if l.fs:IsShown() and l.fs:GetText() == text and l.key == key then
            l.age = 0
            l.fs:SetAlpha(1)
            return
        end
    end
    for i = #lines, 2, -1 do moveLine(lines[i], lines[i - 1]) end
    local top = lines[1]
    top.fs:SetText(text)
    top.fs:SetAlpha(1)
    top.colour = { r or 1, g or 0.1, b or 0.1 }
    top.fs:SetTextColor(top.colour[1], top.colour[2], top.colour[3], 1)
    top.age, top.key = 0, key
    top.fs:Show()
    self.active = true
end

-- s6-ui-core (build 41): a message's three seconds are counted in drawn frames, each at most a tenth of a second, so a long
-- frame (a restyle, a map's load) does not use them up before it is seen: the Cycle Graphics Style's "Mode: Retro" went by
-- unseen behind its own restyle on a loaded machine.
errors:SetScript("OnUpdate", function(self, elapsed)
    if not self.active then return end
    local step = math.min(elapsed or 0, 0.1)
    local any = false
    for _, l in ipairs(self.lines) do
        if l.fs:IsShown() then
            l.age = l.age + step
            local age = l.age
            if age > 3 then l.fs:Hide() else
                any = true
                if age > 2 then l.fs:SetAlpha(3 - age) end
            end
        end
    end
    self.active = any
end)

--- A short yellow message at the top of the screen, also written to the log. key (optional): the kind of message, whose
--- shown line a new one replaces (errors:AddMessage).
function TK.Notify(text, key)
    errors:AddMessage(text, 1, 0.82, 0, key)
    __tk:Log(text)
end

-- ----- pop-up notices (one at a time, queued), for things the user must read: recovered or unsaved settings -----

local popup, queue = nil, {}

local function showNext()
    local item = table.remove(queue, 1)
    if not item then
        popup:Hide()
        return
    end
    popup.title:SetText(item.title or "Notice")
    popup.text:SetText(item.text)
    local h = popup.text:GetStringHeight()
    popup:SetHeight(math.max(130, h + 96))
    popup:Show()
end

--- Shows a notice with an OK button. Several notices queue up.
function TK.Popup(text, title)
    if not popup then
        popup = W.PopupPanel(W.Panel(UIParent, "TKPopup")) -- s6-ui-core (round 55): solid, over any window
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetFrameLevel(100)
        popup:SetWidth(470)
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        popup:EnableMouse(true)
        popup.title = W.Label(popup, "", 15, W.gold)
        popup.title:SetPoint("TOP", popup, "TOP", 0, -14)
        popup.text = W.Label(popup, "", 13, W.white)
        popup.text:SetWordWrap(true)
        popup.text:SetWidth(430)
        popup.text:SetPoint("TOP", popup.title, "BOTTOM", 0, -10)
        popup.ok = W.Button(popup, "OK", 100, 24, "red", function() showNext() end)
        popup.ok:SetPoint("BOTTOM", popup, "BOTTOM", 0, 14)
        popup:Hide()
        TK.Escape:AddWindow(popup, showNext)
    end
    __tk:LogWarning((title or "Notice") .. ": " .. text)
    queue[#queue + 1] = { text = text, title = title }
    if not popup:IsShown() then showNext() end
end

--- A question with Yes and No (Escape is No); onYes runs on Yes, and (s6-library round 16) onNo, when given, on No.
function W.Confirm(text, onYes, onNo)
    local c = W.confirm
    if not c then
        c = W.PopupPanel(W.Panel(UIParent, "TKConfirm")) -- s6-ui-core (round 55): solid, over any window
        c:SetFrameStrata("FULLSCREEN_DIALOG")
        c:SetFrameLevel(110)
        c:SetSize(400, 120)
        c:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        c:EnableMouse(true)
        c.text = W.Label(c, "", 14, W.white)
        c.text:SetWordWrap(true)
        c.text:SetWidth(360)
        c.text:SetPoint("TOP", c, "TOP", 0, -24)
        c.yes = W.Button(c, "Yes", 100, 26, "red", function()
            local fn = c.onYes
            c:Hide()
            if fn then fn() end
        end)
        c.yes:SetPoint("BOTTOMRIGHT", c, "BOTTOM", -8, 16)
        -- s6-library round 16: No (and Escape) runs the question's onNo.
        local function no()
            local fn = c.onNo
            c:Hide()
            if fn then fn() end
        end
        c.no = W.Button(c, "No", 100, 26, nil, no)
        c.no:SetPoint("BOTTOMLEFT", c, "BOTTOM", 8, 16)
        c:Hide()
        TK.Escape:AddWindow(c, no)
        W.confirm = c
    end
    c.text:SetText(text)
    c.onYes, c.onNo = onYes, onNo
    c:Show()
end

--- The owner's hotfix (2026-10-06): a question with a column of choices, { { text, fn } }; the first is Cancel (Escape
--- too). Used by a panel switch's key clashes (core/interfaces.lua T:AskClashes).
function W.Choose(text, choices)
    local c = W.choose
    if not c then
        c = W.PopupPanel(W.Panel(UIParent, "TKChoose"))
        c:SetFrameStrata("FULLSCREEN_DIALOG")
        c:SetFrameLevel(110)
        c:SetWidth(460)
        c:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        c:EnableMouse(true)
        c.text = W.Label(c, "", 14, W.white)
        c.text:SetWordWrap(true)
        c.text:SetWidth(420)
        c.text:SetPoint("TOP", c, "TOP", 0, -20)
        c.buttons = {}
        c:Hide()
        TK.Escape:AddWindow(c, function()
            local first = c.choices and c.choices[1]
            c:Hide()
            if first and first[2] then first[2]() end
        end)
        W.choose = c
    end
    c.text:SetText(text)
    c.choices = choices
    local y = -32 - c.text:GetStringHeight()
    for i, choice in ipairs(choices) do
        local b = c.buttons[i]
        if not b then
            b = W.Button(c, "", 420, 26, "red", function()
                local fn = c.choices[i][2]
                c:Hide()
                if fn then fn() end
            end)
            c.buttons[i] = b
        end
        b:SetText(choice[1])
        b:ClearAllPoints()
        b:SetPoint("TOP", c, "TOP", 0, y)
        b:Show()
        y = y - 32
    end
    for i = #choices + 1, #c.buttons do c.buttons[i]:Hide() end
    c:SetHeight(12 - y)
    c:Show()
end

--- True while a notice is shown (tests and screenshot mode check this).
function TK.PopupShown() return popup ~= nil and popup:IsShown() end

--- s6-modular-g round 22: our notice and question boxes keep their keys until dismissed.
--- They have no counterpart in 4a; passing a key to UserPane::HandleKeyOrTextEvent (0x005A5BD0)
--- would run a command behind the question and change what the server sees.
function W.QuestionShown()
    return TK.PopupShown() or (W.confirm and W.confirm:IsShown()) == true or (W.choose and W.choose:IsShown()) == true
end

-- ----- keeping big windows on the screen (review F5, head note 7.3) -----

local fitted = {}

--- Shrinks a window (never enlarges it) so all of it fits the screen at the current UI scale, and moves it back
--- onto the screen if it is off. Called when it opens; again whenever the window size or the UI scale changes.
--- margin is kept free around it; extraTop and extraRight allow for parts drawn outside the frame (a title plate,
--- side tabs).
TK.OnWithdraw(function()
    for f in pairs(fitted) do
        if TK.IsDead(f) then fitted[f] = nil end
    end
end)

function TK.FitToScreen(frame, margin, extraTop, extraRight)
    margin = margin or 12
    extraTop = extraTop or 0
    extraRight = extraRight or 0
    fitted[frame] = { margin = margin, extraTop = extraTop, extraRight = extraRight }
    local sw, sh = GetScreenWidth(), GetScreenHeight()
    local parentScale = frame:GetParent() and frame:GetParent():GetEffectiveScale() or 1
    local w, h = frame:GetWidth() + extraRight, frame:GetHeight() + extraTop
    if w <= 0 or h <= 0 then return end
    local s = math.min(1, (sw - 2 * margin) / (w * parentScale), (sh - 2 * margin) / (h * parentScale))
    frame:SetScale(math.max(0.2, s))
    local l, b, rw, rh = TK.Util.RootRect(frame)
    if not l then return end
    local es = frame:GetEffectiveScale()
    local top = b + rh + extraTop * es
    if l < 0 or b < 0 or l + rw + extraRight * es > sw or top > sh then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", -extraRight / 2, -extraTop / 2)
    end
end

local function refit()
    for frame, o in pairs(fitted) do
        if frame:IsShown() then TK.FitToScreen(frame, o.margin, o.extraTop, o.extraRight) end
    end
end
TK.On("DISPLAY_SIZE_CHANGED", refit)
TK.On("UI_SCALE_CHANGED", refit)

-- ----- windows, right-click menus and prompts (s6-ui-next) -----

--- A movable window with a title, a close box, Escape closing it, and its contents below the title. Shown last,
--- it is drawn on top (Escape's windows are toplevel).
function make.Window(S, name, title, width, height)
    local f = make.Panel(S, UIParent, name)
    make.TitleBand(S, f)
    f:SetFrameStrata("HIGH")
    f:SetSize(width, height)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:EnableMouse(true)
    -- s6-modular-g (round 21, the owner's research on presses reaching the wrong place): a wheel turn over the window is
    -- the window's (its lists take theirs first). It went to what is under it: a chat log scrolled, or a dialog's list,
    -- which asks the server for older rows at its end (UIHost.Wheel). WIRE: those rows are 3B 02, MailListPane 0x0047AD80
    -- and ArticleListPane 0x00474EC0 (components/dialogs/kit.lua), which 4a sends only for a wheel turn over its list; with
    -- one of our windows over the list, 4a has no such window, so the list is not under the pointer. Changing this changes
    -- what the server sees.
    f:EnableMouseWheel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f.title = make.Label(S, f, title, 16, S.gold)
    f.title:SetPoint("TOP", f, "TOP", 0, -12)
    local x = W.IconButton(f, "tk:close", 16, function() f:Hide() end)
    f.close = x -- s6-macros: the close box (the macro window wires it to the macro dialog's OK)
    x:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    f:Hide()
    TK.On("PLAYER_LEAVING_WORLD", function() f:Hide() end)
    TK.Escape:AddWindow(f)
    function f:Toggle() self:SetShown(not self:IsShown()) end
    return f
end

local menu

--- A right-click menu at the cursor (or at anchor's bottom right): entries { text = "...", action = { kind, slot,
--- amount, text }, onClick = fn, disabled = bool, title = bool }. An entry's action is attached to its row, so a click
--- runs what the row had when the press began (plan 5.9); onClick is for entries that only change the UI. A click
--- elsewhere or Escape closes the menu.
function W.OpenMenu(entries, anchor)
    if not menu then
        menu = CreateFrame("Frame", "TKContextMenu", UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        -- A solid background: the panel texture, or an alpha just under 1, lets what is under a list show through.
        -- s6-ui-core (round 49; Astra's item 5): a solid charcoal and a muted amber row under the cursor, as the drop-down
        -- lists have them.
        menu:SetBackdrop({ bg = W.menuBg, edge = W.panelEdge, bgFile = "tk:white" })
        menu:EnableMouse(true)
        menu.items = {}
        menu:Hide()
    end
    for _, item in ipairs(menu.items) do item:Hide() end
    local width = 120
    for i, e in ipairs(entries) do
        local item = menu.items[i]
        if not item then
            item = CreateFrame("Button", "TKContextMenuItem" .. i, menu)
            item:SetHeight(20)
            item.hl = item:CreateTexture(nil, "HIGHLIGHT")
            item.hl:SetAllPoints(item)
            item.hl:SetColorTexture(W.menuHighlight[1], W.menuHighlight[2], W.menuHighlight[3], W.menuHighlight[4])
            item.label = W.Label(item, "", 12, W.white, "LEFT")
            item.label:SetPoint("LEFT", item, "LEFT", 10, 0)
            menu.items[i] = item
        end
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * 20)
        item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, -4 - (i - 1) * 20)
        item.label:SetText(e.text)
        color(item.label, e.title and W.gold or (e.disabled and W.grey or W.white))
        if e.title or e.disabled then item:Disable() else item:Enable() end
        TK.Actions:SetTable(item, e.action)
        item:SetScript("OnClick", function()
            menu:Hide()
            if e.action then TK.Actions:RunFrozen() end
            if e.onClick then e.onClick() end
        end)
        item:Show()
        width = math.max(width, item.label:GetStringWidth() + 24)
    end
    menu:SetSize(width + 8, #entries * 20 + 8)
    menu:ClearAllPoints()
    if anchor then
        menu:SetPoint("TOPLEFT", anchor, "BOTTOMRIGHT", 0, 0)
    else
        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", TK.Util.CursorRoot())
    end
    menu:Show()

end

function W.CloseMenu()
    if menu and menu:IsShown() then
        menu:Hide()
        return true
    end
    return false
end

TK.On("GLOBAL_MOUSE_DOWN", function()
    if menu and menu:IsShown() and not TK.Util.MouseWithin(menu) then menu:Hide() end
end)

local prompt

--- A small modal question with an edit box: { title, text, numeric = bool, maxLetters, default, action = fn(value),
--- onOk = fn(value) }. action turns the typed value into an action table (or nil for none); it is attached to OK and
--- to the box as the player types, so OK or Enter runs what they held when pressed (plan 5.9). onOk is for prompts
--- that only change the UI. Cancel or Escape closes it.
function W.Prompt(opts)
    if not prompt then
        prompt = W.PopupPanel(W.Panel(UIParent, "TKPrompt")) -- s6-ui-core (round 56; the head's note): solid, a popup
        prompt:SetFrameStrata("FULLSCREEN_DIALOG")
        prompt:SetSize(340, 132)
        prompt:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
        prompt:EnableMouse(true)
        -- s6-modular-g round 22 (Astra's final r21 review): a press on the title or blank interior
        -- keeps the amount field's keyboard just as the outside catcher does. WIRE: 4a's modal
        -- DialogPane::HandleKeyOrTextEvent (0x0049E6E0) precedes UserPane's hotkeys; letting the
        -- next digit escape can send 1C/0F. Changing this changes what the server sees.
        local function keepAmountFocus() prompt.box:SetFocus() end
        prompt:SetScript("OnMouseDown", keepAmountFocus)
        prompt.title = W.Label(prompt, "", 15, W.gold)
        prompt.title:SetPoint("TOP", prompt, "TOP", 0, -12)
        prompt.text = W.Label(prompt, "", 12, W.white)
        prompt.text:SetPoint("TOP", prompt.title, "BOTTOM", 0, -6)
        prompt.box = W.EditBox(prompt, 220, 24)
        prompt.box:SetPoint("TOP", prompt.text, "BOTTOM", 0, -8)
        local function ok()
            local value = prompt.box:GetText()
            local fn, action = prompt.onOk, prompt.actionFn
            prompt:Hide()
            if action then TK.Actions:RunFrozen() end
            if fn then fn(value) end
        end
        prompt.box:SetScript("OnEnterPressed", ok)
        prompt.box:SetScript("OnTextChanged", function()
            local a = prompt.actionFn and prompt.actionFn(prompt.box:GetText()) or nil
            TK.Actions:SetTable(prompt.ok, a)
            TK.Actions:SetTable(prompt.box, a)
        end)
        prompt.box:SetScript("OnEscapePressed", function() prompt:Hide() end)
        prompt.ok = W.Button(prompt, "OK", 90, 24, "red", ok)
        prompt.ok:SetPoint("BOTTOMRIGHT", prompt, "BOTTOM", -6, 12)
        prompt.cancel = W.Button(prompt, "Cancel", 90, 24, nil, function() prompt:Hide() end)
        prompt.cancel:SetPoint("BOTTOMLEFT", prompt, "BOTTOM", 6, 12)
        -- s6-modular-g r23 (final r22 review): an aborted button click and a right press leave the prompt open.
        -- Keep the field on the PRESS, before a release can miss the button. WIRE: EventDispatcher 0x004A7130
        -- gives a modal amount dialog every key before UserPane 0x005A5BD0; letting a digit escape changes
        -- what the server sees. Hook the existing button script so its sound and actual OK/Cancel stay intact.
        prompt.ok:HookScript("OnMouseDown", keepAmountFocus)
        prompt.cancel:HookScript("OnMouseDown", keepAmountFocus)
        -- s6-modular-g (round 21, the owner's research on presses reaching the wrong place): modal, as said above. A
        -- catcher over the screen under it (FULLSCREEN: over the windows, under the popups) takes a press or a wheel turn
        -- beside it and keeps the box's keys through the press and release. Before, a click beside it walked (or talked: 43 01),
        -- and took the box's focus, so the amount typed next ran the game's keys (1 to 0: the hotkeys). Our own window.
        -- WIRE: a press it takes reaches no map pane (MapPane::HandlePointerOrMouseEvent 0x00507150: the click-move walk's
        -- 06/32/11, RequestObjectInfo 0x0050F4D0's 43 01, the look's 0A) and its keys no hotkey (1C, 0F); 4a's amount
        -- prompts are modal dialogs, which take every key and click (EventDispatcher.cpp:264-270). Changing this changes
        -- what the server sees.
        local catcher = CreateFrame("Frame", "TKPromptCatcher", UIParent)
        catcher:SetFrameStrata("FULLSCREEN")
        catcher:SetAllPoints(UIParent)
        catcher:EnableMouse(true)
        catcher:EnableMouseWheel(true)
        catcher:SetScript("OnMouseDown", keepAmountFocus)
        catcher:SetScript("OnMouseUp", keepAmountFocus)
        catcher:Hide()
        prompt:SetScript("OnShow", function() catcher:Show() end)
        prompt:SetScript("OnHide", function()
            catcher:Hide()
            prompt.box:ClearFocus()
        end)
        prompt:Hide()
    end
    prompt.title:SetText(opts.title or "")
    prompt.text:SetText(opts.text or "")
    prompt.onOk = opts.onOk
    prompt.actionFn = opts.action
    prompt.box:SetNumeric(opts.numeric and true or false)
    prompt.box:SetMaxLetters(opts.maxLetters or 0)
    prompt.box:SetText(opts.default or "")
    prompt:Show()

    prompt.box:SetFocus()
end

function W.ClosePrompt()
    if prompt and prompt:IsShown() then
        prompt:Hide()
        return true
    end
    return false
end

-- Escape (plan D21, the original's order): a modal prompt first, as the original's newest modal dialog and its
-- command line take Escape before anything else (DialogPane::HandleKeyOrTextEvent, LineInputPane); then an open
-- right-click menu, as the original's popups close on any key; only then the bow draw and the map selection.
TK.Escape:AddCancel("prompt", 2, function() return W.ClosePrompt() end)
TK.Escape:AddCancel("menu", 4, function() return W.CloseMenu() end)
