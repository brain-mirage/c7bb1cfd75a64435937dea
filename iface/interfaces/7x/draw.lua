-- s6-interface-7x-b (round 8, the interface separation's step 5: docs/development/interface-separation.md, the row for
-- interfaces/7x/hud.lua): 7.x's drawing helpers, the original client's dialog kit (interfaces/original/dialogkit.lua)
-- made with 7.x's skin and its 1024 x 768 screen, one set for 7.x's panels and its dialogs look alike. The panels (the
-- messages' and the chat log's bars, the map name's and the say mode's texts and frames) took them from the dialogs look's
-- file before (require("interfaces.7x.dialogs").X); the look builds its windows on these (its X). Drawing only, except
-- the input routing the kit keeps (its X.List, X.Blocker and X.SlideOpen: WIRE there).

local S = require("interfaces.7x.skin")

local X = require("interfaces.original.dialogkit")({
    skin = S,
    screen = { width = S.WIDTH, height = S.HEIGHT },
    -- a window of 7.x's look placed when it has just opened: the look's own placement (L.Place); the look requires this
    -- file, so it is loaded before any of its windows opens
    place = function(win) require("interfaces.7x.dialogs").Place(win) end,
})

-- 4a's standard window: DLGFRAME.EPF in PAL01.PAL, 14-pixel tiles (DialogPane::DrawBackground and DrawBorder)
X.DIALOG_FRAME = { file = "DLGFRAME.EPF", palette = "PAL01.PAL", tile = 14 }

return X
