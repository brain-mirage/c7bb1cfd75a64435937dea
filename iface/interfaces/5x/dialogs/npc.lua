-- s6-interface-5x (the 5.x interface: docs/development/jobs/s6-interface-5x/PLAN.md, "The dialogs look"): 5.x's look of
-- the NPC dialogs (components/dialogs/npc.lua), from 5.33's own constructors: MessageDialog 0x00492430,
-- MenuQuestionDialog 0x00492C40 and TextDialog 0x00493830; and (s6-interface-5x-b, round 8) the Nexonclub registration,
-- NexonclubRegistrationDialog 0x0047C3C0 (L.Nexonclub, below). 5.33 has no larger windows: each picks its picture by
-- whether it has the text window (contents.textWindow) and the portrait (portrait kinds 1, 2, 3, 5 and 6:
-- contents.picture), in NPAL8.PAL (the small windows' pictures name none: BARAM.PAL). Its buttons are 5.33's image
-- buttons, 72 x 16 (X.Image: 14 OK, 15 CLOSE, 18 PREVIOUS, 19 NEXT; the small message window's bars 52 PREVIOUS, 51
-- NEXT, 53 CLOSE). The windows open at their placement slot, 1: centred on (320, 240) by 5.33's defaults (L.Place).
-- Drawing only: the controls, their indexes, the keys and what is sent are the renderers' and the model's, the same
-- in every look; the rectangles decide which control a press reaches, as in 5.33.

return function(L, X)
    local function textWindow(win) return not (win.view and win.view.contents.textWindow == false) end
    local function hasPicture(win) return win.view and type(win.view.contents.picture) == "table" end

    --- The small windows have no portrait (5.33 adds ObjectImageControlPane only to the text window).
    local function smallWindow(win)
        if win.portrait then win.portrait:Hide() end
    end

    -- The text window (314 x 246): DLGMSG1 with the portrait at (36, 39)-(71, 92), DLGMSG11 without; PREVIOUS, NEXT and
    -- CLOSE along y 196-212; the text (84, 40)-(273, 186) beside the portrait, (39, 37)-(275, 127) without. The small
    -- window (316 x 214, DLGMSG2): BUTT002's bars, no text.
    L.Message = {
        width = 314, height = 246, button = 72,
        place = function(win) X.Portrait(win, 36, 39, 71, 92) end,
        text = function() end,
        fit = function(win)
            if textWindow(win) then
                local pic = hasPicture(win)
                X.Size(win, 314, 246)
                X.Art(win, pic and "DLGMSG1.EPF" or "DLGMSG11.EPF", "NPAL8.PAL")
                X.Image(win, win.prev, 18, 44, 196, 116, 212)
                X.Image(win, win.next, 19, 121, 196, 193, 212)
                X.Image(win, win.close, 15, 198, 196, 270, 212)
                if pic then X.Text(win.text, win, 84, 40, 273, 186) else X.Text(win.text, win, 39, 37, 275, 127) end
                win.text:Show()
            else
                X.Size(win, 316, 214)
                X.Art(win, "DLGMSG2.EPF")
                X.Image(win, win.prev, 52, 77, 88, 235, 103)
                X.Image(win, win.next, 51, 77, 106, 235, 121)
                X.Image(win, win.close, 53, 77, 124, 235, 139)
                win.text:Hide()
                smallWindow(win)
            end
        end,
    }

    -- The text window (374 x 316): DLGMSG3 with the portrait at (36, 40)-(71, 88), DLGMSG31 without; the prompt (86, 29)-
    -- (336, 92) beside the portrait, (55, 22)-(320, 67) without; the answers' list (36, 101)-(338, 245) of 302-pixel
    -- cells in 12-pixel rows (ListPane(514, 16, 302, 12)); OK, PREVIOUS, NEXT and CLOSE along y 266-282. The small
    -- window (374 x 286, DLGMSG4): the list (36, 71)-(338, 215) and the buttons along y 236-252, no prompt.
    L.Question = {
        width = 374, height = 316, button = 72, listWidth = 302, listHeight = 144,
        place = function(win) X.Portrait(win, 36, 40, 71, 88) end,
        text = function() end,
        fit = function(win)
            local text = textWindow(win)
            if text then
                local pic = hasPicture(win)
                X.Size(win, 374, 316)
                X.Art(win, pic and "DLGMSG3.EPF" or "DLGMSG31.EPF", "NPAL8.PAL")
                X.List(win, win.list, 36, 101, 338, 245, 302)
                if pic then X.Text(win.text, win, 86, 29, 336, 92) else X.Text(win.text, win, 55, 22, 320, 67) end
                win.text:Show()
            else
                X.Size(win, 374, 286)
                X.Art(win, "DLGMSG4.EPF")
                X.List(win, win.list, 36, 71, 338, 215, 302)
                win.text:Hide()
                smallWindow(win)
            end
            local y = text and 266 or 236
            for i, b in ipairs({ win.ok, win.prev, win.next, win.close }) do
                X.Image(win, b, ({ 14, 18, 19, 15 })[i], 40 + (i - 1) * 74, y, 112 + (i - 1) * 74, y + 16)
            end
        end,
    }

    -- The text window (374 x 246): DLGMSG5 with the portrait at (37, 40)-(71, 92), DLGMSG51 without; the NPC's text
    -- (97, 35)-(302, 123) beside the portrait, (59, 37)-(313, 125) without; the prompt (54, 125)-(319, 137), the edit
    -- (54, 141)-(319, 153) in 0x80 and the caption (54, 158)-(319, 170); OK, PREVIOUS, NEXT and CLOSE along y 196-212.
    -- The small window (374 x 194, DLGMSG6): the same prompt, edit and caption, and the four buttons on the window's
    -- rectangle (0, 0)-(374, 194), as 5.33 sets their rectangles only for the text window (7.5.2's TextDialog the same).
    --
    -- Input routing (wire): a press goes to the last control whose rectangle holds it (DialogPane_HitTestControls
    -- 0x004215F0), so in the small window a press on the prompt (5), the edit (6) or the caption (7) is theirs and any
    -- other press is CLOSE's (4). Here the buttons are one frame level apart in that order, under the edit and the
    -- texts' blockers (X.Blocker), as 7.x's look stacks them (the kit's X.Stacked). Changing the order or the rectangles changes which control
    -- a press reaches, so what the client sends.
    L.TextReply = {
        width = 374, height = 246, button = 72, editWidth = 265, editHeight = 12,
        place = function(win)
            X.Portrait(win, 37, 40, 71, 92)
            X.Text(win.prompt, win, 54, 125, 319, 137)
            X.Edit(win.edit, win, 54, 141, 319, 153)
            X.Text(win.caption, win, 54, 158, 319, 170)
            win.x7over = X.Stacked(win, { win.ok, win.prev, win.next, win.close })
            X.Blocker(win.x7over, win, 54, 125, 319, 137)
            win.edit:SetParent(win.x7over)
            X.Blocker(win.x7over, win, 54, 158, 319, 170)
        end,
        text = function() end,
        fit = function(win)
            local buttons, ids = { win.ok, win.prev, win.next, win.close }, { 14, 18, 19, 15 }
            if textWindow(win) then
                local pic = hasPicture(win)
                X.Size(win, 374, 246)
                X.Art(win, pic and "DLGMSG5.EPF" or "DLGMSG51.EPF", "NPAL8.PAL")
                if pic then X.Text(win.text, win, 97, 35, 302, 123) else X.Text(win.text, win, 59, 37, 313, 125) end
                win.text:Show()
                for i, b in ipairs(buttons) do X.Image(win, b, ids[i], 40 + (i - 1) * 74, 196, 112 + (i - 1) * 74, 212) end
            else
                X.Size(win, 374, 194)
                X.Art(win, "DLGMSG6.EPF")
                win.text:Hide()
                smallWindow(win)
                for i, b in ipairs(buttons) do X.Image(win, b, ids[i], 0, 0, 374, 194) end
            end
        end,
    }

    -- s6-interface-5x-b (round 8, s6-interface-5x's Y2): the Nexonclub registration (0x30 kind 9), 5.33's own window
    -- (NexonclubRegistrationDialog 0x0047C3C0, which 4a keeps as its classic layout of 0x0052F950): 375 x 286 on DLGNC.EPF
    -- in NPAL8.PAL; the prompt (40, 30)-(336, 153); the id (2) (126, 171)-(216, 183) and the masked password (3) (126,
    -- 191)-(216, 203), font 0 in 0x80 with no frame; OK (4, image 14) (77, 236)-(149, 252), CANCEL (5, image 22) (154,
    -- 236)-(226, 252), the web site's registration (6, image 32) (231, 236)-(303, 252).
    L.Nexonclub = {
        width = 375, height = 286, button = 72, editWidth = 90, editHeight = 12,
        place = function(win)
            X.Art(win, "DLGNC.EPF", "NPAL8.PAL")
            X.Text(win.text, win, 40, 30, 336, 153)
            win.text:SetWordWrap(true)
            X.Edit(win.account, win, 126, 171, 216, 183)
            X.Edit(win.password, win, 126, 191, 216, 203)
            X.Image(win, win.ok, 14, 77, 236, 149, 252)
            X.Image(win, win.cancel, 22, 154, 236, 226, 252)
            X.Image(win, win.create, 32, 231, 236, 303, 252)
        end,
    }
end
