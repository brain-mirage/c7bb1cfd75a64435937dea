-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md): 5.33's icon row, IconsPane
-- (constructor 0x00442560) at (263, 374)-(422, 388) of the 640 x 480 screen: eight icons of ICONS.EPF in NPAL7.PAL, 20
-- pixels apart, 19 x 14 each (IconsPane_GetIconRect 0x00442D90); an icon pressed shows its frame + 8 while the pointer
-- stays on it, and its release there activates it (IconsPane__HandlePointerOrMouseEvent 0x00442740, cases 1, 0, 3).
--
-- 7.5.2 keeps the same pane (4a ui/IconsPane.cpp, ActivateIcon 0x004CF8E0), and an icon here runs what that icon runs
-- in 7.5.2, through the opener or the action a key already has for it, so it sends what the key sends:
--   0 Items   the items' opener (the side panel's items: the game layer's view, TK.Game.Views)
--   1 Spells  the spell book's opener (the side panel's spells)
--   2 Info    the character's opener with its request, open:character (2D 00; RequestLocalPlayerStatus)
--   3 Users   userlist (18; OpenUserList)            4 Board  boards (3B 01; EnsureNormalBulletinSession)
--   5 Talk    chat:current (OpenInputPaneForCurrentSayMode)
--   6 Help    helpmenu (43 01 FFFFFFFF 0004 0000; SendOpcode43Packet)
--   7 Quit    the quit prompt (dialog:open QuitDialog; j_OpenQuitPrompt)
-- An icon's actions are set once and run on its release (TK.Actions:RunFrozen), as the micro menu's buttons run theirs;
-- the rules decide what each sends (and that none acts before the player's status, m_waitingForLocalPlayerStatus, as
-- for the keys). Changing an icon's action changes what the server sees.
-- s6-interface-5x-b: a right press on an icon shows its help line for 5 s (case 4: SimpleHelpPane with 5.33's lines
-- 200-207, 7.5.2's 202-209 in its string table; interfaces/5x/help.lua); and the options' ACTION ICONS (C:SetAll,
-- the 5.x options window) shows all eight or only Help and Quit, as IconsPane::ShowReducedIcons (0x00442640: the paint
-- and the hit test start at icon 6). Local: nothing is sent.

local C = TK.GetComponent("5x.icons")
local S = require("interfaces.5x.skin")
local Screen = require("interfaces.screen")
local Help = require("interfaces.5x.help") -- s6-interface-5x-b

local PLACE = { 263, 374 }

--- Each icon's action (nil: an opener only) and what its release does.
local ICONS = {
    { name = "Items", run = function() TK.Game.Views.Toggle("bag") end },
    { name = "Spells", run = function() TK.Game.Views.Toggle("spellbook") end },
    { name = "Info", action = { kind = "open:character" },
      run = function() TK.Game.Views.Toggle("character") end },
    { name = "Users", action = { kind = "userlist" } },
    { name = "Board", action = { kind = "boards" } },
    { name = "Talk", action = { kind = "chat:current" } },
    { name = "Help", action = { kind = "helpmenu" } },
    { name = "Quit", action = { kind = "dialog:open", text = "QuitDialog" } },
}

function C:OnEnable()
    local f = CreateFrame("Frame", "TK5xIcons", UIParent)
    f:SetFrameStrata("LOW")
    f:SetSize(159, 14)
    f.icons = {}
    for i, def in ipairs(ICONS) do
        local b = CreateFrame("Button", "TK5xIcon" .. def.name, f)
        b:SetSize(19, 14)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 20 * (i - 1), 0)
        b.normal = S.Picture(b, nil, "ICONS.EPF", i - 1, "NPAL7.PAL", 0, 0, "ARTWORK")
        b.pushed = S.Picture(b, nil, "ICONS.EPF", i + 7, "NPAL7.PAL", 0, 0, "ARTWORK")
        b:SetNormalTexture(b.normal)
        b:SetPushedTexture(b.pushed)
        b:RegisterForClicks("LeftButtonUp")
        if def.action then TK.Actions:SetTable(b, def.action) end
        -- the release on the pressed icon (IconsPane's case 3): an opener (Info's request runs as its page shows) or
        -- the icon's action, frozen at its press
        b:SetScript("OnClick", function()
            if def.run then def.run() else TK.Actions:RunFrozen() end
        end)
        -- s6-interface-5x-b: its help line, the owner the whole row as 5.33's pane
        Help.OnRightPress(f, function() return Help.String(201 + i) end, b)
        f.icons[i] = b
    end
    f:Hide()
    self:Own(f)
    self.frame = f
    self.entry = Screen.Register(f, "5x.icons", "5.x Icons", function() return self:DB().enabled == true end)
end

--- At 5.33's place on the scaled 5.x screen unless moved, at the screen's scale times its own; in the game only.
function C:ApplySettings()
    if not self.frame then return end
    Screen.PlacePanel(self, S.WIDTH, S.HEIGHT, PLACE[1], PLACE[2])
    -- s6-interface-5x-b: all eight, or Help and Quit only (IconsPane::ShowAllIcons / ShowReducedIcons)
    local db = self:DB()
    for i, b in ipairs(self.frame.icons) do b:SetShown(db.allIcons ~= false or i >= 7) end
end

--- s6-interface-5x-b: the options' ACTION ICONS (Config's byte 1118 in 5.33, IconsPane's field_F8): all eight icons, or
--- Help and Quit only. Kept in the profile; local.
function C:SetAll(on)
    self:DB().allIcons = on and true or false
    TK.DB:MarkDirty()
    self:ApplySettings()
end

function C:ShowsAll() return self:DB().allIcons ~= false end

Screen.Follow(C, "ApplySettings")
