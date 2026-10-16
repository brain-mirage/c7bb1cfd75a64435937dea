-- s6-ui-core (round 86; decision 2026-10-12-original-pregame-screens): 5.x's own title screen, 5.33's MainMenuPane
-- (0x457250, OnPaint 0x4591E0), its Login entry's LoginDialogPane (0x45A0C0) and (round 88) its new account entry's
-- NewCreateUserDialogPane (0x47A0E0). Its layout is title.xml's; its script
-- is the twins' shared one (interfaces/xml/title.lua: the menu, the dialog, and the WIRE note on OK and the wait), made
-- with 5.x's kit. 5.x is a look over 7.5.2, so what it sends is 7.5.2's, as on 7.x's title. Only the XML twin has it,
-- and only with the 5.33 set (its pictures): without it ours shows.

local S = require("interfaces.5x.skin")

local data = TK.Xml.Data("title.xml")

return require("interfaces.xml.title")({
    data = data,
    load = function(opts)
        local ui = TK.Xml.Load("title.xml", opts) -- (not a tail call: the loader finds title.xml beside this file)
        return ui
    end,
    S = S,
    X = require("interfaces.5x.dialogs").X,
    elements = require("interfaces.5x.elements"),
    -- OK, the dialog's focused control, has 5.33's focus frame, 1 pixel in 0x80 round it (X.Image's edge); the New
    -- User's OK and Cancel have it while they have the keyboard (on: false takes it off)
    focus = function(button, on)
        button.x5focus = on ~= false
        for _, e in ipairs(button.x5edge or {}) do e:SetShown(button.x5focus) end
    end,
    available = function() return S.Image(data.ITEMS.selected, 0, data.ITEMS.selectedPalette) ~= nil end,
    -- Story and History, 5.33's HistoryViewingPane (constructor 0x45E620): its own STORY.EPF and HISTORY.EPF in its
    -- NPAL4.PAL (OnPaint 0x45E920), from frame 0 a frame a turn (its key and pointer handlers 0x45E7F0 and 0x45E8A0, which
    -- 7.5.2's AdvancePage frame 3 jump is not in); Enter, Escape, Space or a release turns, and the last page's turn
    -- closes it, as 7.5.2's. Its 10 s timer's handler does nothing (0x45E890). Nothing is sent.
    book = {
        Image = function(file, frame) return S.Image(file, frame, "NPAL4.PAL") end,
        Turn = function(page) return page + 1 end,
    },
})
