-- s6-devtools (round 5; the interface separation's step 5: docs/development/interface-separation.md 4.4, open question
-- 49): the original client's alerts, for any dialogs look that draws 4a's windows: require("interfaces.original.alerts")
-- (L, X) installs L.Alert in look L, drawn with its helpers X (interfaces/original/dialogkit.lua: its skin, its screen's
-- centre X.CENTRE, its standard window X.DIALOG_FRAME). Moved from 7.x's look (interfaces/7x/dialogs/alerts.lua,
-- s6-modular-g's phase 4), which 5.x's look ran too: 5.33's AlertPane (0x00421BA0) has 7.5.2's numbers to the pixel. A
-- window the look does not draw (no win.lookEntry) is its fallback look's (X.Fallback, which the look sets). Drawing only:
-- the buttons' indexes, the keys (Y and N for the quit) and what is sent are the renderer's and the model's.
--
-- 4a's AlertPane (0x0049FEB0) and the classes built on it (QuitDialog, UrlAlertPane, ConnectionClosedDialog,
-- ReconnectDialog, CopyWindow, VersatileAlertPane and the mail and transfer replies), and ExchangeAlertPane (0x004B0490,
-- a DialogPane of its own drawn the same way).
--
-- AlertPane: the standard window (DialogPane::DrawBackground and DrawBorder: DLGFRAME.EPF in PAL01.PAL); the message in
-- font 0, colour 0x80, at (24, 24)-(W - 24, H - 56) (H - 24 without buttons), wrapped at its one-line width clamped to
-- 160-240 with two buttons, 74-240 with one, at most 240 with none; W = that + 48, H = the wrapped text + 80 (+ 48
-- without buttons); its buttons 4a's text buttons, 74 x 20: two at (W - 184, H - 44) and (W - 98, H - 44), one at
-- (W - 98, H - 44); the Enter frame round the primary, which is also the selected button (its own frame in colour 1);
-- centred on the screen, unclamped; it slides open (DialogPane::SlideOpenVertical, X.SlideOpen). Its size is the kit's
-- X.AlertSize (interfaces/original/dialogkit.lua), which the interfaces' own login screens' alerts use too.
--
-- ExchangeAlertPane (the trade's result): the same window, message and buttons by the same numbers, the Enter frame
-- round its OK, no selected button; centred on the trade window it ends, kept on the screen by DialogPane::AddToLayer's
-- clamps; it slides open.

return function(L, X)
    L.Alert = {
        width = 288, height = 92, button = 74, buttonHeight = 20,
        -- where it opens (the look's place): AlertPane's AddToLayer centres it on the screen (X.CENTRE), unclamped;
        -- ExchangeAlertPane's centre is the trade window's (on 4a's place of the look's trade window: the screen's
        -- centre otherwise, where 4a's opens), clamped
        centre = function(win)
            if win.className ~= "ExchangeAlertPane" then return X.CENTRE[1], X.CENTRE[2], false end
            for _, other in pairs(TK.Dialogs.Windows()) do
                if other.className == "ExchangeDialog" and other.screenX then
                    return other.screenX + math.floor(other:GetWidth() / 2), other.screenY + math.floor(other:GetHeight() / 2), true
                end
            end
            return X.CENTRE[1], X.CENTRE[2], true
        end,
        place = function(win)
            if not win.lookEntry then return X.Fallback.Alert.place(win) end
            win.url:Hide()
        end,
        fit = function(win, hasUrl)
            if not win.lookEntry then return X.Fallback.Alert.fit(win, hasUrl) end
        end,
        buttons = function(win, two)
            if not win.lookEntry then return X.Fallback.Alert.buttons(win, two) end
            local c = win.view and win.view.contents or {}
            local n = (c.primary ~= nil and 1 or 0) + (c.secondary ~= nil and 1 or 0)
            local w, h = X.AlertSize(win.text, n) -- AlertPane's size (the kit's)
            local opened = win.opened
            X.Size(win, w, h)
            -- the look's standard window
            X.Frame(win, w, h, X.DIALOG_FRAME.file, X.DIALOG_FRAME.palette, X.DIALOG_FRAME.tile)
            X.Text(win.text, win, 24, 24, w - 24, n > 0 and h - 56 or h - 24)
            win.text:SetJustifyH("LEFT")
            if n == 2 then
                X.TextButton(win, win.b1, w - 184, h - 44, w - 110, h - 24)
                X.TextButton(win, win.b2, w - 98, h - 44, w - 24, h - 24)
            elseif n == 1 then
                X.TextButton(win, win.b1, w - 98, h - 44, w - 24, h - 24)
            end
            for _, btn in ipairs({ win.b1, win.b2 }) do if btn.placeCaption then btn.placeCaption() end end
            X.EnterFrame(win, n > 0 and win.b1 or nil) -- the Enter frame round the primary
            -- the primary is the selected button (AlertPane: SetControlSelected(true)): its own frame in colour 1; none in
            -- ExchangeAlertPane
            local selected = n > 0 and win.b1:IsEnabled() and win.className ~= "ExchangeAlertPane"
            for _, tex in ipairs(win.b1.selectedFrame or {}) do tex:SetShown(selected) end
            for _, tex in ipairs(win.b2.selectedFrame or {}) do tex:Hide() end
            if opened then X.SlideOpen(win) end
        end,
    }
end
