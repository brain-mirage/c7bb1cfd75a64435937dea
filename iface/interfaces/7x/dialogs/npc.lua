-- s6-modular-g (interfaces, phase 4): 7.x's look of the NPC dialogs (components/dialogs/npc.lua), from Source-5's
-- class pages: MessageDialog 0x0054CE10 and MessageDialogLarger 0x0054DB90, MenuQuestionDialog and its Larger,
-- TextDialog 0x00552110. Each picks its picture and its controls' rectangles by 4a's flags (contents.textWindow: 1 the
-- text window, 0 the small one), its size bit (contents.larger) and whether it has the portrait (portrait kinds 1, 2,
-- 3, 5 and 6: contents.picture). Image ids: 14 OK, 15 CLOSE, 18 PREVIOUS, 19 NEXT; 55-57 the small window's bars.
-- Drawing only: the controls' indexes, the keys and what is sent are the renderers' and the model's.
-- s6-ui-core (round 85): the XML twin's; the windows' sizes, pictures and the parts' places are npc.xml's (core/xml.md).

local unpack = table.unpack
local entry = require("interfaces.original.entry")
local D = TK.Xml.Data("npc.xml")

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

    --- Image buttons along a row: button i's image images[i] at x + (i - 1) * step, w wide, from top to bottom.
    local function row(win, buttons, images, x, step, w, top, bottom)
        for i, b in ipairs(buttons) do X.Image(win, b, images[i], x + (i - 1) * step, top, x + (i - 1) * step + w, bottom) end
    end

    -- D-01, D-02: the text window (Larger: wider) with Previous, Next, Close; the small window with BUTT002's bars, no text
    local M = D.Message
    L.Message = entry(M, {
        place = function(win) X.Portrait(win, unpack(M.portrait)) end,
        text = function() end,
        fit = function(win)
            local pic, big = hasPicture(win), larger(win)
            if textWindow(win) then
                local t = M.text
                local v = big and t.larger or t.normal
                X.Size(win, v.width, v.height)
                X.Art(win, pic and v.picture or v.plain, t.palette)
                row(win, { win.prev, win.next, win.close }, t.images, v.x, t.step, M.button, t.top, t.bottom)
                X.Text(win.text, win, unpack(pic and v.withPicture or v.without))
                win.text:Show()
            else
                local s = M.small
                X.Size(win, s.width, s.height)
                X.Art(win, s.file, s.palette)
                X.Image(win, win.prev, unpack(s.prev))
                X.Image(win, win.next, unpack(s.next))
                X.Image(win, win.close, unpack(s.close))
                win.text:Hide()
                smallWindow(win)
            end
        end,
    })

    -- D-03, D-04: the prompt, the answers' list, OK, Previous, Next, Close; the small window's list and buttons higher
    local Q = D.Question
    L.Question = entry(Q, {
        place = function(win) X.Portrait(win, unpack(Q.portrait)) end,
        text = function() end,
        fit = function(win)
            local pic, big = hasPicture(win), larger(win)
            local buttons = { win.ok, win.prev, win.next, win.close }
            local t = Q.text
            local v = big and t.larger or t.normal
            if textWindow(win) then
                X.Size(win, v.width, v.height)
                X.Art(win, pic and v.picture or v.plain, t.palette)
                row(win, buttons, Q.images, v.x, t.step, Q.button, t.top, t.bottom)
                local l = v.list
                X.List(win, win.list, l[1], l[2], l[3], l[4], v.cell)
                X.Text(win.text, win, unpack(pic and v.withPicture or v.without))
                win.text:Show()
            else
                local s = Q.small
                X.Size(win, s.width, s.height)
                X.Art(win, s.file, s.palette)
                smallWindow(win)
                row(win, buttons, Q.images, s.x, s.step, Q.button, s.top, s.bottom)
                local l = s.list
                X.List(win, win.list, l[1], l[2], l[3], l[4], v.cell)
                win.text:Hide()
            end
        end,
    })

    -- D-05: the NPC's text, the prompt, the edit and its caption, OK, Previous, Next, Close.
    --
    -- Input routing (wire): 4a gives a press to the last control whose rectangle holds it (DialogPane::HitTestControls
    -- 0x0049FB10), a disabled one taking it to no effect; so in the small window a press on the prompt (5), the edit (6)
    -- or the caption (7) is theirs and any other press is CLOSE's (4). Here the buttons are one frame level apart in that
    -- order, under the edit and the texts' blockers (X.Blocker). Changing the order or the rectangles (npc.xml's)
    -- changes which control a press reaches, so what the client sends.
    local T = D.TextReply
    L.TextReply = entry(T, {
        place = function(win)
            X.Portrait(win, unpack(T.portrait))
            X.Text(win.prompt, win, unpack(T.prompt))
            X.Edit(win.edit, win, unpack(T.edit))
            X.Text(win.caption, win, unpack(T.caption))
            -- 4a's control order, the last on top (above; X.Stacked, WIRE there): the buttons each a level above the one
            -- before, and the prompt's blocker (5), the edit (6) and the caption's blocker (7) in one above them all
            win.x7over = X.Stacked(win, { win.ok, win.prev, win.next, win.close })
            X.Blocker(win.x7over, win, unpack(T.prompt))
            win.edit:SetParent(win.x7over)
            X.Blocker(win.x7over, win, unpack(T.caption))
        end,
        text = function() end,
        fit = function(win)
            local pic = hasPicture(win)
            local buttons = { win.ok, win.prev, win.next, win.close }
            if textWindow(win) then
                local t = T.text
                X.Size(win, t.width, t.height)
                X.Art(win, t.file, t.palette)
                X.Text(win.text, win, unpack(pic and t.withPicture or t.without))
                win.text:Show()
                row(win, buttons, T.images, t.x, t.step, T.button, t.top, t.bottom)
            else
                local s = T.small
                X.Size(win, s.width, s.height)
                X.Art(win, s.file, s.palette)
                win.text:Hide()
                smallWindow(win)
                for i, b in ipairs(buttons) do X.Image(win, b, T.images[i], unpack(s.buttons)) end
            end
        end,
    })

    -- D-07 (s6-interface-7x-b, round 7): the Nexonclub registration, its picture carrying the labels
    local N = D.Nexonclub
    L.Nexonclub = entry(N, {
        place = function(win)
            X.Art(win, unpack(N.art))
            X.Text(win.text, win, unpack(N.text))
            win.text:SetWordWrap(true)
            X.Edit(win.account, win, unpack(N.account))
            X.Edit(win.password, win, unpack(N.password))
            -- s6-characters r51, input equivalence: 4a's constructor 0x0052F950 gives the edits these tall hit areas
            -- (npc.xml's accountHit and passwordHit); DialogPane::HitTestControls 0x0049FB10 chooses password 3 over
            -- account 2, then buttons 4/5/6 over both. Its pointer handler 0x0049E240 hit-tests before checking the outer
            -- pane, so the areas below y=214 also take focus. Keep the visible edit lines above separate invisible
            -- frames, using the kit's existing press/release routing. Changing the selected edit changes the values sent
            -- to the server by later commands.
            local K = TK.GetComponent("dialogs").kit
            local function focusArea(index, rect)
                local hit = CreateFrame("Frame", nil, win)
                X.Rect(hit, win, unpack(rect))
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
            win.accountHit = focusArea(2, N.accountHit)
            win.passwordHit = focusArea(3, N.passwordHit)
            -- The later password frame wins the overlap. The drawn lines retain their normal edit input, and the
            -- buttons stay above both hit areas as later controls in 0x0049FB10; changing this can change a server reply.
            win.x7over = CreateFrame("Frame", nil, win)
            win.x7over:SetAllPoints(win)
            for _, control in ipairs({ win.account, win.password, win.ok, win.cancel, win.create }) do
                control:SetParent(win.x7over)
            end
            X.Image(win, win.ok, unpack(N.ok))
            X.Image(win, win.cancel, unpack(N.cancel))
            X.Image(win, win.create, unpack(N.create))
        end,
    })
end
