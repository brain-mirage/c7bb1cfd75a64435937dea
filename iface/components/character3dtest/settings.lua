-- s6-modular-b (round 13; the owner, 2026-10-03): the Experimental tab's 3D Character Test. "Remove the option to select
-- the 3d character in any menu by default. Have a single option in Experimental called 3d Character Test. If you turn it
-- on it temporarily overrides the character setting in the menu, it does not actually change it, and clicking it off
-- reverts it back to whatever you had it as like 7x 5x etc."
--
-- Round 14 (the owner, 2026-10-03: "If you set something in OUR menu is it not persisting between closing/opening???";
-- docs/user-related/decisions/2026-10-03-3d-character-test-saved.md): the toggle is saved in the profile like every other
-- setting, and main.lua applies it (TK.Modular.Draw.Characters3d). The Characters choice it draws over is never changed.
-- Like the World Renderer page beside it, the page is at the login screen and in the game (s6-ui-core, build 41: no Allow
-- Switching During Gameplay any more).
--
-- s6-reprojection (round 29; the head's note, QA's next43): round 26's 3D Map Objects toggle is gone from this page: it is
-- the Graphics Styles page's Map Objects choice "3D" (TK.Modular.Draw.MapObjects3d), and main.lua carries a profile's old
-- toggle over to it once.

local C = TK.GetComponent("character3dtest")

C.defaults = { testing = false }

function C:SettingsNodes()
    return { {
        id = "character3dtest", title = "3D Character Test", order = self.order, category = "experimental",
        atLogin = true,
        db = function() return self:DB() end,
        defaults = function() return self.defaults end,
        tabs = { { name = "3D Character Test", args = {
            { type = "description", name = "Experimental: what is on this tab may change or go." },
            { type = "toggle", key = "testing", name = "3D Character Test" },
            { type = "description", name = "On, every character is drawn in 3D, whatever the Characters style chosen on the Asset Styles page; the choice stays as it is, and the page still shows it. Off, characters are drawn in that style again at once. New Character's preview stays 2D. Nothing is sent: the server sees no difference." },
        } } },
    } }
end
