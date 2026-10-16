-- The social panel (plan D19): the group and the ignore list, the default UI's route to the original's group and
-- ignore commands (its f, g and F9 keys).
--
--   Group    the members as the server lists them (0x63 02), and Invite (the original's g: 2E with a name). Opening
--            it is opening the original's group tab, so it asks for the list (2D 01, plan D20); the party frames,
--            always visible, never ask.
--   Ignore   the character's ignore list on this server, as the session holds it (read from the character's store at
--            the login, as 4a reads its .usr, and kept there as the rules change it: s6-layout round 5), sent again by
--            the session on each world entry (0D 02 per name), with Add (0D 02) and Remove (0D 03).
--
-- Invite, Add and Remove are actions carried by their prompts' OK (TK.Actions); until the Social rules exist they are
-- logged and nothing is sent.
--
-- It is the window of the game layer's views "group" and "ignore" (TK.Game.Views, s6-interface-5x round 12, step 1),
-- whose keys are TOGGLEGROUP (F, the original's group key) and TOGGLESOCIAL (F9, the original's ignore key).
--
-- s6-ui-core (round 85): the XML twin's scripts; the window, its tabs and pages are social.xml's (core/xml.md).

local H = __tk
local W = require("interfaces.modern.skin").UI -- s6-devtools (round 5, the separation's step 5): Modern's skin

local S = { page = "group" }
TK.Social = S

local window

-- s6-rules-items (head note 23): the rules changed the session's block list (ignore, hear again); the host has kept it in
-- the character's store (s6-layout round 5), so the page only shows it again.
TK.On("TK_BLOCKLIST", function()
    if window and window:IsShown() then S:Refresh() end
end)

-- the scripts social.xml names, and its build (its template: the window)
local scripts = {}
local ui = TK.Xml.Load("social.xml", { scripts = scripts, elements = require("interfaces.modern.elements") })

function scripts.Own(w) TK.GetComponent("windows"):Own(w) end

function scripts.Tab(b) b:GetParent().tabs[b.id] = b end

function scripts.OpenTab(b) TK.Game.Views.Open(b.id, "input") end

-- Wire: the Group tab carries the group page's request, its 2D 01 (NewGroupPane::OnActivate 0x0056CB80); changing which
-- control carries it changes what the server sees.
function scripts.GroupRequest(b) TK.Actions:Set(b, "open:group") end

-- Wire: the group page asks for the list each time it becomes visible (2D 01, D20: NewGroupPane::OnActivate 0x0056CB80);
-- changing it changes what the server sees.
function scripts.GroupOpen(g) TK.Actions:SetOpen(g, "open:group") end

function scripts.Invite()
    W.Prompt({ title = "Invite", text = "Name of the new group member?", maxLetters = 15,
        action = TK.Game.Social.InviteAction })
end

function scripts.Ignore()
    W.Prompt({ title = "Ignore", text = "Who do you wish to ignore?", maxLetters = 15,
        action = TK.Game.Social.IgnoreAction })
end

function scripts.HearAgain()
    W.Prompt({ title = "Hear again", text = "Who do you wish to hear?", maxLetters = 15,
        action = TK.Game.Social.UnignoreAction })
end

function scripts.Changed() if window:IsShown() then S:Refresh() end end

local function build() window = ui:New("Window") end

-- The group page's request can be attached only while the UI loads (plan 5.9): the window is made now.
TK.On("PLAYER_LOGIN", function() if not window then build() end end)

function S:Refresh()
    for id, b in pairs(window.tabs) do b:SetSelected(id == self.page) end
    window.group:SetShown(self.page == "group")
    window.ignore:SetShown(self.page == "ignore")
    local lines = {}
    -- s6-ui-character (K-097): six members from the first shown, as NewGroupPane's m_firstVisibleMember and its six rows
    -- (SelfLookPane.cpp:2792), of the game layer's group list (TK.Game.Social.GroupMembers: the player's own included).
    local members = TK.Game.Social.GroupMembers()
    local count = #members
    self.first = math.max(0, math.min(self.first or 0, count - 6))
    for i = self.first + 1, math.min(self.first + 6, count) do
        local m = members[i]
        lines[#lines + 1] = string.format("%s   vita %d/%d   mana %d/%d", m.name, m.hp, m.hpMax, m.mp, m.mpMax)
    end
    if #lines == 0 then lines[1] = H:IsOnline() and "Not in a group." or "Offline: the group comes from the server." end
    window.group.list:SetText(table.concat(lines, "\n"))
    local ignored = TK.Game.Social.Ignored()
    window.ignore.list:SetText(#ignored > 0 and table.concat(ignored, "\n") or "Nobody is ignored.")
end

--- s6-ui-character (K-097): PgUp and PgDn on the group page move its first shown member by 6, as NewGroupPane's keys
--- (0x93 back to 0 at least, 0x94 on to the member count less 6 at most); nothing is sent.
function S:PageGroup(delta)
    if not (window and window:IsShown() and self.page == "group") then return end
    self.first = (self.first or 0) + 6 * delta
    self:Refresh()
end

--- Shows the window on a page (the views' window: TK.Game.Views has switched the tab and asked the interfaces' pages
--- first); showing the group page asks for the member list (2D 01), as the original's group tab, when an input froze
--- its request (plan 5.9).
local function showWindow(page)
    if not window then build() end
    S.page = page or S.page
    -- The page first, then the window: only the page that shows asks.
    S:Refresh()
    window:Show()
end

--- The micro menu's Social button: the window on the page last shown, or closed when open. s6-interface-5x (round 12,
--- step 1): the button's opening is
--- the view's, so the group page is 4a's SwitchActiveTab(4) and an interface that shows the group itself shows it
--- (TK.Game.Views); its closing switches nothing, as before. Wire: the tab decides E and G's sender
--- (UserPane.cpp:1584-1614) and whether the group's next press sends 2D 01; changing it changes what the server sees.
function S:Toggle()
    if self:IsOpen() then window:Hide() else TK.Game.Views.Open(self.page, "input") end
end

function S:IsOpen() return window ~= nil and window:IsShown() end

-- s6-interface-5x (round 12, step 1): the window of the game layer's views "group" and "ignore" (TK.Game.Views). PgUp and
-- PgDn page its group page last (pageOrder: after the look window, the character window and the bag).
TK.Game.Views.SetWindow({ "group", "ignore" }, {
    panel = { component = "windows", node = "social", switch = "enabled" }, -- its switch (Modern's panel; step 1)
    pageOrder = 4,
    Open = showWindow,
    Close = function() if window then window:Hide() end end,
    IsOpen = function(view) return S:IsOpen() and (view == nil or S.page == view) end,
    Page = function(delta)
        if not (S:IsOpen() and S.page == "group") then return false end
        S:PageGroup(delta)
        return true
    end,
})
