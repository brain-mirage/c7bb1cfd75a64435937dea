-- The game menu (review F4): Escape, when there is nothing left to close, opens it, as in WoW. It is part of the
-- core, not a component, so no setting can remove it: Settings, Key Bindings and Edit Mode are always reachable
-- even with the micro menu disabled or hidden. Escape is handled before any key binding and cannot be rebound.

local W = TK.UI

local G = {}
TK.GameMenu = G

local menu
local entries = {}

--- Adds a button to the game menu: { id, text, order, onClick, label = function() return text end, shown = fn,
--- action = the kind its press freezes (a D20 window's request for Settings) }.
function G:AddEntry(e)
    entries[#entries + 1] = e
    table.sort(entries, function(a, b) return (a.order or 50) < (b.order or 50) end)
end

local function build()
    menu = W.Panel(UIParent, "TKGameMenu")
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(20)
    menu:SetWidth(230)
    menu:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    menu:EnableMouse(true)
    -- s6-modular-g (round 21, the owner's research on presses reaching the wrong place): a wheel turn over it is its own,
    -- as over every window (core/widgets.lua's make.Window); it scrolled what lay under it.
    -- WIRE: ArticleListPane::HandlePointerOrMouseEvent (0x00474EC0) can request older board rows
    -- on a wheel turn. Letting this turn reach it changes what the server sees.
    menu:EnableMouseWheel(true)
    menu.title = W.Label(menu, "Game Menu", 15, W.gold)
    menu.title:SetPoint("TOP", menu, "TOP", 0, -14)
    menu.buttons = {}
    menu:Hide()
    TK.Escape:AddWindow(menu, function() G:Close() end)
end

local function layout()
    local y = -42
    local n = 0
    for _, e in ipairs(entries) do
        local b = menu.buttons[e.id]
        if not b then
            b = W.Button(menu, e.text, 190, 26, e.style)
            b:SetScript("OnClick", function() TK.SafeCall(e.onClick) end)
            if e.action then TK.Actions:Set(b, e.action) end
            menu.buttons[e.id] = b
        end
        local shown = e.shown == nil or e.shown()
        b:SetShown(shown)
        if shown then
            b:SetText(e.label and e.label() or e.text)
            b:ClearAllPoints()
            b:SetPoint("TOP", menu, "TOP", 0, y)
            y = y - 32
            n = n + 1
        end
    end
    menu:SetHeight(-y + 12)
end

function G:Open()
    if not menu then build() end
    layout()
    menu:Show()
    TK.FitToScreen(menu)
end

function G:Close()
    if menu then menu:Hide() end
end

function G:IsOpen() return menu ~= nil and menu:IsShown() end

function G:Toggle()
    if self:IsOpen() then self:Close() else self:Open() end
end

G:AddEntry({ id = "settings", text = "Settings", order = 10, style = "red", action = "open:music",
    onClick = function() G:Close(); TK.Settings:Open() end })
-- s6-ui-core (round 31): the key-bindings list, as WoW's Game Menu opens it; the hover binding is its Quick Keybind Mode.
G:AddEntry({ id = "keybindings", text = "Key Bindings", order = 20,
    onClick = function() G:Close(); TK.Settings:Open("keybindings", "General") end,
    shown = function() return TK.GameState == nil or TK.GameState:InWorld() end })
G:AddEntry({ id = "editmode", text = "Edit Mode", order = 30,
    label = function() return TK.EditMode:IsOpen() and "Close Edit Mode" or "Edit Mode" end, -- s6-ui-core (round 54)
    onClick = function() G:Close(); TK.EditMode:Toggle() end,
    shown = function() return TK.GameState == nil or TK.GameState:InWorld() end })
G:AddEntry({ id = "reload", text = "Reload UI", order = 80, onClick = function() G:Close(); ReloadUI() end })
G:AddEntry({ id = "return", text = "Return to Game", order = 100, onClick = function() G:Close() end })


