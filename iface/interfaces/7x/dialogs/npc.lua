-- s6-modular-g (interfaces, phase 4): 7.x's look of the NPC dialogs (components/dialogs/npc.lua), from Source-5's
-- class pages: MessageDialog 0x0054CE10 and MessageDialogLarger 0x0054DB90, MenuQuestionDialog and its Larger,
-- TextDialog 0x00552110. Each picks its picture and its controls' rectangles by 4a's flags (contents.textWindow: 1 the
-- text window, 0 the small one), its size bit (contents.larger) and whether it has the portrait (portrait kinds 1, 2,
-- 3, 5 and 6: contents.picture). Image ids: 14 OK, 15 CLOSE, 18 PREVIOUS, 19 NEXT; 55-57 the small window's bars.
-- Drawing only: the controls' indexes, the keys and what is sent are the renderers' and the model's.

return function(L, X)
    --- 4a's flags for the dialog in the window (1 unless the model says the small window).
    local function textWindow(win) return not (win.view and win.view.contents.textWindow == false) end
    local function hasPicture(win) return win.view and type(win.view.contents.picture) == "table" end
    local function larger(win) return win.view and win.view.contents.larger == true end

    --- The small window has no portrait: 4a adds it (ObjectImageControlPane) only under flags, to the text window (the
    --- kit shows the model's picture at each update, before the look's fit).
    local function smallWindow(win)
        if win.portrait then win.portrait:Hide() end
    end

    -- D-01, D-02: the text window (364 x 283; Larger 472 x 283): DLGMSG1 (or DLGMSG1B) with the portrait, DLGMSG11
    -- without, DLGMSG1.PAL; Previous, Next, Close along y 211-235; the portrait at (46, 36). The small window (316 x 214,
    -- DLGMSG2 in BARAM.PAL): BUTT002's bars PREV 56, NEXT 55, QUIT 57, and no text.
    L.Message = {
        width = 364, height = 283, button = 63,
        place = function(win) X.Portrait(win, 46, 36) end,
        text = function() end,
        fit = function(win)
            local pic, big = hasPicture(win), larger(win)
            if textWindow(win) then
                X.Size(win, big and 472 or 364, 283)
                X.Art(win, pic and (big and "DLGMSG1B.EPF" or "DLGMSG1.EPF") or "DLGMSG11.EPF", "DLGMSG1.PAL")
                local x = big and 131 or 77
                X.Image(win, win.prev, 18, x, 211, x + 63, 235)
                X.Image(win, win.next, 19, x + 77, 211, x + 140, 235)
                X.Image(win, win.close, 15, x + 154, 211, x + 217, 235)
                if big then
                    if pic then X.Text(win.text, win, 122, 60, 415, 204) else X.Text(win.text, win, 48, 48, 326, 208) end
                elseif pic then
                    X.Text(win.text, win, 122, 60, 307, 204)
                else
                    X.Text(win.text, win, 48, 60, 312, 204)
                end
                win.text:Show()
            else
                X.Size(win, 316, 214)
                X.Art(win, "DLGMSG2.EPF", "BARAM.PAL")
                X.Image(win, win.prev, 56, 77, 88, 235, 103)
                X.Image(win, win.next, 55, 77, 106, 235, 121)
                X.Image(win, win.close, 57, 77, 124, 235, 139)
                win.text:Hide()
                smallWindow(win)
            end
        end,
    }

    -- D-03, D-04: the text window (383 x 345; Larger 491 x 345): DLGMSG3 (DLGMSG3B) with the portrait at (42, 32),
    -- DLGMSG31 without, DLGMSG3.PAL; the prompt, the answers' list (12-pixel rows of 269-pixel cells, the Larger's 302:
    -- MenuQuestionItemList, MenuQuestionItemListLarger), OK, Previous, Next, Close along y 283-307. The small window
    -- (374 x 286, DLGMSG4 in BARAM.PAL): the list and the buttons higher, no prompt.
    L.Question = {
        width = 383, height = 345, button = 63, listWidth = 302, listHeight = 120,
        place = function(win) X.Portrait(win, 42, 32) end,
        text = function() end,
        fit = function(win)
            local pic, big = hasPicture(win), larger(win)
            local buttons = { win.ok, win.prev, win.next, win.close }
            local ids = { 14, 18, 19, 15 }
            if textWindow(win) then
                X.Size(win, big and 491 or 383, 345)
                X.Art(win, pic and (big and "DLGMSG3B.EPF" or "DLGMSG3.EPF") or "DLGMSG31.EPF", "DLGMSG3.PAL")
                local x = big and 105 or 51
                for i, b in ipairs(buttons) do X.Image(win, b, ids[i], x + (i - 1) * 74, 283, x + (i - 1) * 74 + 63, 307) end
                X.List(win, win.list, 50, 149, big and 450 or 342, 269, big and 302 or 269)
                if big then
                    -- without the portrait 4a gives the larger window's prompt (55, 22)-(320, 67) (a slip in 4a, kept)
                    if pic then X.Text(win.text, win, 122, 50, 440, 134) else X.Text(win.text, win, 55, 22, 320, 67) end
                elseif pic then
                    X.Text(win.text, win, 122, 50, 332, 134)
                else
                    X.Text(win.text, win, 47, 50, 319, 134)
                end
                win.text:Show()
            else
                X.Size(win, 374, 286)
                X.Art(win, "DLGMSG4.EPF", "BARAM.PAL")
                smallWindow(win)
                for i, b in ipairs(buttons) do X.Image(win, b, ids[i], 40 + (i - 1) * 74, 236, 40 + (i - 1) * 74 + 63, 260) end
                X.List(win, win.list, 36, 71, 338, 215, big and 302 or 269)
                win.text:Hide()
            end
        end,
    }

    -- D-05: the text window (383 x 258, DLGMSG5 in DLGMSG5.PAL, the portrait at (30, 30)): the NPC's text, the prompt,
    -- the edit and its caption, OK, Previous, Next, Close along y 197-221. The small window (374 x 194, DLGMSG6 in
    -- BARAM.PAL): the same prompt, edit and caption, and the four buttons on the window's rectangle (0, 0)-(374, 194), as
    -- 4a sets their rectangles only for the text window (TextDialog 0x00552110): stacked in their order (OK 1,
    -- PREVIOUS 2, NEXT 3, CLOSE 4), each picture at the window's top left, CLOSE's on top.
    --
    -- Input routing (wire): 4a gives a press to the last control whose rectangle holds it (DialogPane::HitTestControls
    -- 0x0049FB10), a disabled one taking it to no effect; so in the small window a press on the prompt (5), the edit (6)
    -- or the caption (7) is theirs and any other press is CLOSE's (4). Here the buttons are one frame level apart in that
    -- order, under the edit and the texts' blockers (X.Blocker). Changing the order or the rectangles changes which
    -- control a press reaches, so what the client sends.
    L.TextReply = {
        width = 383, height = 258, button = 63, editWidth = 265, editHeight = 12,
        place = function(win)
            X.Portrait(win, 30, 30)
            X.Text(win.prompt, win, 45, 144, 310, 156)
            X.Edit(win.edit, win, 49, 163, 314, 175)
            X.Text(win.caption, win, 45, 182, 310, 194)
            -- 4a's control order, the last on top (above; X.Stacked, WIRE there): the buttons each a level above the one
            -- before, and the prompt's blocker (5), the edit (6) and the caption's blocker (7) in one above them all
            win.x7over = X.Stacked(win, { win.ok, win.prev, win.next, win.close })
            X.Blocker(win.x7over, win, 45, 144, 310, 156)
            win.edit:SetParent(win.x7over)
            X.Blocker(win.x7over, win, 45, 182, 310, 194)
        end,
        text = function() end,
        fit = function(win)
            local pic = hasPicture(win)
            local buttons, ids = { win.ok, win.prev, win.next, win.close }, { 14, 18, 19, 15 }
            if textWindow(win) then
                X.Size(win, 383, 258)
                X.Art(win, "DLGMSG5.EPF", "DLGMSG5.PAL")
                if pic then X.Text(win.text, win, 110, 50, 331, 123) else X.Text(win.text, win, 47, 50, 335, 140) end
                win.text:Show()
                for i, b in ipairs(buttons) do X.Image(win, b, ids[i], 49 + (i - 1) * 74, 197, 49 + (i - 1) * 74 + 63, 221) end
            else
                X.Size(win, 374, 194)
                X.Art(win, "DLGMSG6.EPF", "BARAM.PAL")
                win.text:Hide()
                smallWindow(win)
                for i, b in ipairs(buttons) do X.Image(win, b, ids[i], 0, 0, 374, 194) end
            end
        end,
    }

    -- D-07 (s6-interface-7x-b, round 7): the Nexonclub registration (NexonclubRegistrationDialog::
    -- NexonclubRegistrationDialog, NexonclubRegistrationDialog.cpp:25-50, the EPF branch): 334 x 214 at its slot 1 on
    -- DLGNC.EPF in DLGNC.PAL, no labels of its own (the picture carries them); the text (25, 38)-(330, 131); the account and
    -- the password edits on their lines from (83, 104) and (83, 134), 174 wide; OK (4, image 14) (67, 179)-(130, 203),
    -- CANCEL (5, image 22) (142, 179)-(205, 203), CREATE (6, image 51) (217, 179)-(280, 203). 4a's edits take a press over
    -- taller rectangles ((83, 104)-(257, 220) and (83, 134)-(257, 280), the later control over the earlier).
    L.Nexonclub = {
        width = 334, height = 214, title = "", button = 63, editWidth = 174, editHeight = 12,
        place = function(win)
            X.Art(win, "DLGNC.EPF", "DLGNC.PAL")
            X.Text(win.text, win, 25, 38, 330, 131)
            win.text:SetWordWrap(true)
            X.Edit(win.account, win, 83, 104, 257, 116)
            X.Edit(win.password, win, 83, 134, 257, 146)
            -- s6-characters r51, input equivalence: 4a's constructor 0x0052F950 gives the edits these tall hit areas;
            -- DialogPane::HitTestControls 0x0049FB10 chooses password 3 over account 2, then buttons 4/5/6 over both.
            -- Its pointer handler 0x0049E240 hit-tests before checking the outer pane, so the areas below y=214 also
            -- take focus. Keep the visible edit lines above separate invisible frames, using the kit's existing
            -- press/release routing. Changing the selected edit changes the values sent to the server by later commands.
            local K = TK.GetComponent("dialogs").kit
            local function focusArea(index, t, b)
                local hit = CreateFrame("Frame", nil, win)
                X.Rect(hit, win, 83, t, 257, b)
                hit:EnableMouse(true)
                -- PointInRect 0x004B7E80 is half-open; Unity's raycast includes the far edges. Check this event's
                -- cursor against the same frame bounds (y upwards here). An edge selecting another edit changes
                -- what later commands send to the server.
                local function inBounds()
                    local l, bottom, w, h = TK.Util.RootRect(hit)
                    local x, y = TK.Util.CursorRoot()
                    return x >= l and x < l + w and y > bottom and y <= bottom + h
                end
                K.Control(hit, win, index, 0, inBounds)
                -- The visible edit's raycast includes its right edge too; use the original tall bounds there as
                -- well, so the bottom of a drawn line still belongs to its edit (0x0052F950 / 0x004B7E80, wire above).
                K.Control(win.controls[index], win, index, 0, inBounds)
                K.Wire(win, hit, index)
                return hit
            end
            win.accountHit = focusArea(2, 104, 220)
            win.passwordHit = focusArea(3, 134, 280)
            -- The later password frame wins the overlap. The drawn lines retain their normal edit input, and the
            -- buttons stay above both hit areas as later controls in 0x0049FB10; changing this can change a server reply.
            win.x7over = CreateFrame("Frame", nil, win)
            win.x7over:SetAllPoints(win)
            for _, control in ipairs({ win.account, win.password, win.ok, win.cancel, win.create }) do
                control:SetParent(win.x7over)
            end
            X.Image(win, win.ok, 14, 67, 179, 130, 203)
            X.Image(win, win.cancel, 22, 142, 179, 205, 203)
            X.Image(win, win.create, 51, 217, 179, 280, 203)
        end,
    }
end
