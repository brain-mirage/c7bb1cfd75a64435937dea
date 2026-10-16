-- s6-ui-login: the login's presentation, as the active interface gives it (the owner, 2026-10-04: "a login animation
-- plays and login music from the original. Is there any way to check what interface is selected and only play this if
-- the appropriate interface is enabled? For modern it should just swap to the interface with a black screen with a
-- loading message popup which goes away when the game is loaded"). Each interface's interface.lua says, in `login`:
--   titleMusic     what is heard of the title music, the main menu's, from the greeting (4a's MainMenuPane starts track
--                  999) until its 3 s fade as the world is entered (RestartMusic(3000) at the accepted login): true, the
--                  original's 999; false, nothing; a track number, that track's file in 999's place, nothing when the packs
--                  lack it (no other track stands in); a pack set's name, that set's own 999 in its place (the set beside
--                  the base set: 5.x's "nexustk-5.33", head note 14), nothing without it. s6-ui-core (build 41; the owner, 2026-10-05): only while the Sound
--                  page's Play Login Music is on (off by default); off, nothing is heard in any interface
--                  (components/audio/main.lua).
--   loadingScreen  from the accepted login (the 02, where 4a retires its menu and builds the game screen) until the world
--                  has loaded (the map's wait for the player's own status is over, MapPane.cpp:1012): a black screen with
--                  a small "Loading..." popup, the interface shown over the black once the world is entered. It stands
--                  in for the original's transfer animation (the login's 03 to the game server's 05), which is not
--                  drawn while it shows (round 8: components/dialogs/panes.lua, Transfer). Without it the login screen
--                  stays until the world, and the transfer animation shows over it as in 4a.
-- Modern: the title music (none before s6-ui-core's build 41), the loading screen. 7.x: the title music, no loading
-- screen (4a draws no loading text: while it waits, MapPane::RenderMapView only leaves out the map's objects,
-- MapPane.cpp:2062). 5.x (round 7, s6-interface-5x's
-- reading of 5.33: its FOR-s6-ui-login-r2-533-login-presentation.md): 5.33's own track 999 heard (MainMenuPane
-- 0x457250, StartMusic(999, 100, 1); s6-ui-core round 86: not 231), a recording other than 7.5.2's, from the 5.33 set
-- (head note 14); no loading screen (the game screen comes at once).
-- An interface without its own takes Modern's. The pre-game is no interface's part (docs/development/interfaces.md), so
-- in a profile that mixes interfaces the active interface decides
-- (docs/user-related/decisions/2026-10-04-login-presentation-per-interface.md).
--
-- Wire: drawing and sound only, and the same session in every interface. The title track is still opened, faded and
-- ended by the audio logic, with its draws on the session's random stream; only what is heard changes
-- (AudioHost.SetTitleMusic). The black screen and its popup are drawn over what is there: the login, the transfer,
-- every packet and wait are the session's and do not look at them, and nothing waits for the popup. Before the world the
-- black screen takes the mouse, so the hidden login screen's buttons (Cancel, Quit) cannot be pressed through it, as 4a's
-- menu is gone from the 02; in the world it takes nothing, so the map's clicks reach the world view as without it (and the
-- rules ignore them while the map waits, as 4a does: MapPane.cpp:1458).

local H = __tk
local W = TK.UI

local E = {}
TK.Entering = E

--- The active interface's login presentation, or the default interface's (Modern's) for an interface without its own
--- (s6-input round 49, separation step 4b: TK.Interfaces:Default, no interface named here).
function E.Presentation()
    local active = TK.Interfaces:Active()
    return active and active.login or TK.Interfaces:Get(TK.Interfaces:Default()).login
end

local cover, popup

local function build()
    cover = CreateFrame("Frame", "TKEnteringCover", UIParent)
    cover:SetAllPoints(UIParent)
    cover.black = cover:CreateTexture(nil, "BACKGROUND")
    cover.black:SetAllPoints(cover)
    cover.black:SetColorTexture(0, 0, 0, 1)
    cover:Hide()
    popup = W.Panel(UIParent, "TKEnteringPopup")
    popup:SetFrameStrata("FULLSCREEN")
    popup:SetSize(220, 56)
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    popup.text = W.Label(popup, "Loading...", 16, W.gold)
    popup.text:SetPoint("CENTER", popup, "CENTER", 0, 0)
    popup:Hide()
    -- Gone once the world has loaded (read from the logic's published snapshot each frame while it shows).
    cover:SetScript("OnUpdate", function()
        if TK.GameState:InWorld() and H:IsWorldLoaded() then E:Hide() end
    end)
end

-- Before the world: over the login screen (HIGH), under its alerts. In the world: over the world view (BACKGROUND) and
-- under the interface's panels (MEDIUM and up), taking no clicks.
local function place()
    local world = TK.GameState:InWorld()
    cover:SetFrameStrata(world and "LOW" or "DIALOG")
    cover:SetFrameLevel(world and 100 or 1)
    cover:EnableMouse(not world)
end

--- The loading screen, from the accepted login.
function E:Show()
    if not cover then build() end
    place()
    cover:Show()
    popup:Show()
end

function E:Hide()
    if not cover then return end
    cover:Hide()
    popup:Hide()
end

function E:IsShown() return cover ~= nil and cover:IsShown() end

--- What the active interface has heard of the title (the active interface is fixed from the start): the original's track
--- 999 (ZoneMusic.TitleTrack), none (0), or another track in its place; and the pack set that track's file comes from
--- (nil: the base set). s6-ui-core (build 41): the audio component passes them to AudioHost.SetTitleMusic while Play Login
--- Music is on, and 0 while it is off.
function E.TitleTrack()
    local music = E.Presentation().titleMusic
    if type(music) == "string" then return 999, music end
    return music == true and 999 or type(music) == "number" and music or 0
end

-- From the 02 through the transfer to the world the loading screen stays; any other state (refused, closed, lost, back
-- at the menu) ends it.
local ENTERING = { Accepted = true, Transferring = true, InWorld = true }
TK.On("TK_SESSION_STATE", function(_, state)
    if state == "Accepted" and E.Presentation().loadingScreen then
        E:Show()
    elseif not ENTERING[state] then
        E:Hide()
    end
end)

TK.On("TK_GAME_STATE", function(_, state)
    if state == "world" then
        if E:IsShown() then place() end
    else
        E:Hide()
    end
end)

return E
