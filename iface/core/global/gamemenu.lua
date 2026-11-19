-- The game menu (review F4): Escape, when there is nothing left to close, opens it, as in WoW. It is part of the
-- core, not a component, so no setting can remove it: Settings, Key Bindings and Edit Mode are always reachable
-- even with the micro menu disabled or hidden. Escape is handled before any key binding and cannot be rebound.
-- s6-ui-core (round 124, the Global Interface's C# shell, piece 1; the owner's answer to question A): the window is C#
-- (Runtime/Shell/GameMenu.cs) and works without our Lua, with its own Reload UI and Return to Game. Round 170 (U-64 step
-- 1; the owner, 2026-10-26: the Global Interface is C#, and mods and interfaces add menu items to it): Settings, Key
-- Bindings and Edit Mode, and Esc's closing of the menu, are the shell's too. This file is its Lua face: TK.GameMenu,
-- TKGameMenu and TKGameMenu.buttons.<id> stay, and the entries interfaces and mods add with AddEntry keep their onClick,
-- label and shown in this file, which the shell asks for (__tk_shell, TK.ShellCalls).

local W = TK.UI
local H = __tk

local G = {}
TK.GameMenu = G

local entries = {} -- the entries Lua added, by id
local wrapButton = TK.WrapShellButton

_G.TKGameMenu = TK.Wrap(H:ShellMenuFrame())
TKGameMenu.__name = "TKGameMenu"
TKGameMenu.buttons = setmetatable({}, { __index = function(t, id)
    local b = wrapButton(H:ShellMenuButton(id))
    if b then rawset(t, id, b) end
    return b
end })

--- Adds a button to the game menu: { id, text, order, style, onClick, label = function() return text end, shown = fn,
--- action = the kind its press freezes (a D20 window's request for Settings) }.
function G:AddEntry(e)
    entries[e.id] = e
    local b = wrapButton(H:ShellMenuAdd(e.id, e.text, e.order or 50, e.style))
    -- WIRE: a press of the entry's button freezes this action when the press begins (UIHost's _pressAction,
    -- TakeFrameAction), as on the Lua button before; Settings' open:music reopens the Sound page as 4a's music dialog,
    -- whose constructor (MusicControlDialog::MusicControlDialog 0x00528E60) sends 1B 01 00. Dropping it or setting it
    -- after a press began changes what the server sees.
    if e.action then TK.Actions:Set(b, e.action) end
end

TK.ShellCalls = TK.ShellCalls or {}

-- WIRE: an entry's onClick runs inside the click's own input dispatch: the shell's OnClick handler calls this from
-- UIHost.FireScript, where the Lua button's OnClick script ran, so Log Out's 0B (MapPane::ExitToMenuTeardown 0x005047F0)
-- rides that click's completion. Deferring it changes when the server sees it.
TK.ShellCalls["menu.click"] = function(id)
    local e = entries[id]
    if e then TK.SafeCall(e.onClick) end
end

--- Whether an entry shows, and its label, asked when the menu opens.
TK.ShellCalls["menu.entry"] = function(id)
    local e = entries[id]
    if not e or (e.shown ~= nil and not e.shown()) then return false end
    return true, e.label and e.label() or e.text
end

-- The see-through finish: the UI transparency in the world, solid elsewhere (W.HudPanel's), asked at opening and pushed
-- when it changes while the menu is open (Modern's micro menu opens Settings over it).
local function alpha() return W.FramePanelAlpha(TKGameMenu) end
TK.ShellCalls["menu.alpha"] = alpha
TKGameMenu:RegisterEvent("TK_PANEL_STYLE_CHANGED")
TKGameMenu:SetScript("OnEvent", function() if G:IsOpen() then H:ShellMenuAlpha(alpha()) end end)
TK.ShellCalls["menu.opened"] = function() TK.FitToScreen(TKGameMenu) end

function G:Open() H:ShellMenuOpen() end
function G:Close() H:ShellMenuClose() end
function G:IsOpen() return H:ShellMenuIsOpen() end

function G:Toggle()
    if self:IsOpen() then self:Close() else self:Open() end
end

-- Settings (10), Key Bindings (20), Edit Mode (30), Reload UI (80) and Return to Game (100) are the shell's own.
