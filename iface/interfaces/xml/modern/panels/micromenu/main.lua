-- The micro menu: shortcuts to the character window on its Character and Spell Book tabs, the Bag, the Social panel,
-- Emotes, the Boards (plan D19: the original's b, which has a free key here), the original's Menu popup (s6-rules-dialogs,
-- D-55: Userlook, Board, Mail, UserList, Friends, Target, Hotkey, Profile, Ranking, Quit), Edit Mode (lock / unlock),
-- Settings, and Log Out (back to the login screen).
--
-- s6-ui-settings (the owner, 2026-10-02): each button shows an icon (settings.lua's C.BUTTONS; the character's is the
-- player's bare head, s6-characters' picture made once a login), and its tooltip the key bound to its action now
-- (none when unbound): a key belongs to the action on the Key Bindings page, never to the button. The page's list sets
-- which buttons show and their order (C:Buttons()); the others close up. Mail and Parcel, off by default, are the
-- minimap's mail and parcel icons: the bottom icons' pane's two controls (ParcelPane), pressed and released the same way.
-- s6-ui-core (round 85): the XML twin's scripts; the bar and its buttons are main.xml's (core/xml.md).

local C = TK.GetComponent("micromenu")
local H = __tk

local B = TK.Xml.Data("main.xml").BUTTON

--- The player's bare head (s6-characters' GetBareHead: made once from the first look of a login and held until logout;
--- "" before it and after).
function C:Head()
    return (H:GetBareHead(B.icon))
end

--- A button's icon and its texture coordinates.
function C:Icon(def)
    if def.id == "character" then
        if self.head and self.head ~= "" then return self.head, nil end
        return "emoji:1f9cd", nil   -- a standing person while there is no head (before the first look, offline)
    end
    if def.id == "mail" then return TK.Game.Parcels.Count(1) > 0 and "emoji:1f4eb" or def.icon, nil end
    return def.icon, nil
end

--- The first key bound to one of the button's commands, as the Key Bindings page writes it; nil when none is.
local function boundKey(def)
    for _, command in ipairs(def.commands or {}) do
        local key = GetBindingKey(command)
        if key then return TK.Bindings.KeyText(key) end
    end
end

-- the scripts main.xml names
local scripts = {}

function scripts.Tip(self)
    local def = self.def
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(def.name, 1, 1, 1)
    GameTooltip:AddLine(def.tip, 0.8, 0.8, 0.8)
    local key = boundKey(def)   -- read now: a rebound key shows as rebound
    if key then GameTooltip:AddLine("Key: " .. key, 1, 0.82, 0) end
    GameTooltip:Show()
end

function scripts.Untip() GameTooltip:Hide() end

--- A button of the bar (ui: the build), its face in its hue.
local function microButton(ui, parent, def, onClick)
    -- Named by its title (TKMicroButtonMenu, TKMicroButtonCharacter...): the gate's driver clicks our controls by name
    -- (head note 51). TKMicroMenu is the bar itself.
    local b = ui:New("MicroButton", parent, "TKMicroButton" .. def.name:gsub("%s", ""))
    b:SetSize(B.width, B.height)
    local hue = def.hue
    b.face:SetVertexColor(hue[1], hue[2], hue[3], 1)
    b.pressed:SetVertexColor(hue[1] * 0.6, hue[2] * 0.6, hue[3] * 0.6, 1)
    b.icon:SetSize(B.icon, B.icon)
    b.def = def
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

--- Mail and Parcel: the pane's control (1 the letters, 0 the parcels) takes the press; the release goes to the pane's
--- control under the pointer then. s6-input (round 49, separation step 4b): through the game layer's one press path,
--- TK.Game.Parcels.Wire. Wire: ParcelPane::HandlePointerOrMouseEvent 0x00546610 (1 opens the mail's 3B 09, 0 sends 41);
--- changing a button's control changes what the server sees.
local function parcelButton(ui, parent, def, control)
    return TK.Game.Parcels.Wire(microButton(ui, parent, def), control)
end

--- The buttons, in the bar f, with what each opens.
function scripts.Buttons(f, ui)
    local self = C
    local V = TK.Game.Views -- the game layer's views (s6-interface-5x round 12, step 1): each button opens its view
    local defs = {}
    for _, d in ipairs(C.BUTTONS) do defs[d.id] = d end
    -- buttons[1] to [10] keep today's order (the tests and the gate name them so); Mail and Parcel follow.
    self.buttons = {
        microButton(ui, f, defs.character, function() V.Toggle("character") end),
        microButton(ui, f, defs.spellbook, function() V.Toggle("spellbook") end),
        microButton(ui, f, defs.bag, function() V.Toggle("bag") end),
        -- Modern's own window, on its last page (TK.Social:Toggle: the views' opening). s6-modular-g (round 18, kept = 7
        -- dropped; Astra's pass 18-3): its code is there only while one of Modern's windows is on (step 11); with all of
        -- them off the button opens the group view as that window's Toggle did, its start page, so an interface that shows
        -- the group itself (7.x's side panel) shows it. Wire: that is 4a's SwitchActiveTab(4) and the group's 2D 01
        -- (NewGroupPane::OnActivate 0x0056CB80); changing it changes what the server sees.
        microButton(ui, f, defs.social, function()
            if TK.Components:Loaded("windows") then TK.Social:Toggle() else V.Open("group", "input") end
        end),
        microButton(ui, f, defs.emotes, function() V.Toggle("emotes") end),
        microButton(ui, f, defs.boards, function() TK.Actions:RunFrozen() end),
        microButton(ui, f, defs.menu, function() end),
        microButton(ui, f, defs.editmode, function() TK.EditMode:Toggle() end),
        microButton(ui, f, defs.settings, function() TK.Settings:Toggle() end),
        microButton(ui, f, defs.logout, function() TK.Login:LogOut() end),
    }
    self.mail = parcelButton(ui, f, defs.mail, 1)
    self.parcel = parcelButton(ui, f, defs.parcel, 0)
    self.byId = {}
    for _, b in ipairs(self.buttons) do self.byId[b.def.id] = b end
    self.byId.mail, self.byId.parcel = self.mail, self.parcel
    TK.Actions:Set(self.buttons[6], "boards")
    -- The original opens its popup on the left press (MenuVarietyPane::HandlePointerOrMouseEvent), through the dialogs
    -- (TK.Dialogs.MenuPress, the press's wire; s6-play-modes round 8).
    self.buttons[7]:HookScript("OnMouseDown", function(_, button)
        if TK.Dialogs then TK.Dialogs.MenuPress(button) end
    end)
    -- The buttons that open a D20 window carry its request; the window's page runs it if it shows (plan 5.9).
    TK.Actions:Set(self.buttons[1], "open:character")
    TK.Actions:Set(self.buttons[4], "open:group")
    TK.Actions:Set(self.buttons[9], "open:music")
    -- The head: asked now and when the player's pictures change (the first look of a login brings it, the logout takes it
    -- away); the same picture all through a login, as the owner asked.
    self.head = self:Head()
end

function scripts.PortraitChanged(_, _, unit)
    if unit ~= "player" then return end
    C.head = C:Head()
    C:ShowIcons()
end

-- Mail and Parcel, while shown: "some" or "none" as the minimap's icons, looked at twice a second as the minimap does
-- (its wait is this build's).
function scripts.Ticker(f)
    local wait = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        if not (C.mail:IsShown() or C.parcel:IsShown()) then return end
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.5
        C:ShowIcons()
    end)
end

function C:OnEnable()
    local f = TK.Xml.Load("main.xml", { scripts = scripts }).frame
    self.frame = f
    TK.Visibility:Attach(f, function() return self:DB() end)
    TK.EditMode:Register(f, "micromenu", "Micro Menu", C.defaultPosition, "micromenu")
end

function C:ShowIcons()
    for _, def in ipairs(C.BUTTONS) do
        local b = self.byId[def.id]
        local icon, coords = self:Icon(def)
        b.icon:SetTexture(icon)
        local c = coords or { 0, 1, 0, 1 }
        b.icon:SetTexCoord(c[1], c[2], c[3], c[4])
        if def.id == "parcel" then
            local none = TK.Game.Parcels.Count(0) == 0
            b.icon:SetVertexColor(none and 0.55 or 1, none and 0.55 or 1, none and 0.55 or 1, none and 0.6 or 1)
        end
    end
end

-- C:Buttons (the page's order) is settings.lua's (s6-interface-5x round 13: the page reads it while this is not loaded)

function C:ApplySettings()
    local db = self:DB()
    local pad = db.padding or 2
    local shown = {}
    for _, e in ipairs(self:Buttons()) do
        local b = self.byId[e.id]
        b:SetShown(e.on)
        if e.on then shown[#shown + 1] = b end
    end
    local n = #shown
    -- All off: the panel keeps a button's size, so edit mode still finds it and its page turns them back on.
    local w = math.max(n, 1)
    local BW, BH = B.width, B.height
    if db.vertical then
        self.frame:SetSize(BW, w * BH + (w - 1) * pad)
    else
        self.frame:SetSize(w * BW + (w - 1) * pad, BH)
    end
    for i, b in ipairs(shown) do
        b:ClearAllPoints()
        if db.vertical then
            b:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -(i - 1) * (BH + pad))
        else
            b:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (i - 1) * (BW + pad), 0)
        end
    end
    self:ShowIcons()
    TK.Visibility:Apply(self.frame)
end
