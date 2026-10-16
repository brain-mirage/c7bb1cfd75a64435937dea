-- s6-interface-5x-b (round 6; the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md, "The dialogs look"):
-- 5.x's look of the Power window (components/dialogs/shops.lua, D-30), 5.33's own. Drawing only, but for where each
-- control's press lands: the controls, their indexes and what is sent are the renderer's and the model's.
--
-- 5.33's PowerDialogPane (constructor 0x00490640, paint 0x00490D30) is 4a's (PowerDialogPane.cpp has one branch) to the
-- pixel but for its seven buttons: 5.33's are 72 x 16 at y 307-323 (REDO image 43 at x 47, A-D and COLOR images 38-42 at
-- 120 + 73 k, CLOSE image 30 at 485), 7.5.2's 63 x 24. So 5.x takes the shared layout (interfaces/power.lua, round 7:
-- the lists, the thresholds, the grid, the rows' swatches, its place at (20, 20)) with 5.33's buttons, drawn with this
-- look's helpers and skin (5.33's POWER.EPF, its image buttons, its font 0).
--
-- s6-ui-core (round 85): the XML twin's; the buttons' size and row are shops.xml's (core/xml.md).

local S = require("interfaces.5x.skin")
local P = TK.Xml.Data("shops.xml").Power

return function(L, X)
    L.Power = require("interfaces.power").Entry(X, S, { width = P.width, height = P.height, top = P.top })
end
