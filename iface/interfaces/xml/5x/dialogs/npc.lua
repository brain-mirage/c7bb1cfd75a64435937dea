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
--
-- s6-ui-core (round 85): the XML twin's; the windows' sizes, pictures and the parts' places are npc.xml's (core/xml.md).

local unpack = table.unpack
local entry = require("interfaces.xml.entry")
local D = TK.Xml.Data("npc.xml")

return function(L, X)
    local function textWindow(win) return not (win.view and win.view.contents.textWindow == false) end
    local function hasPicture(win) return win.view and type(win.view.contents.picture) == "table" end

    --- The small windows have no portrait (5.33 adds ObjectImageControlPane only to the text window).
    local function smallWindow(win)
        if win.portrait then win.portrait:Hide() end
    end

    --- The four image buttons along a row at y (their images, from x, step apart, width x height: the spec's).
    local function row(win, buttons, spec, y)
        for i, b in ipairs(buttons) do
            local l = spec.x + (i - 1) * spec.step
            X.Image(win, b, spec.images[i], l, y, l + spec.width, y + spec.height)
        end
    end

    -- The text window: the portrait's picture or the plain one; PREVIOUS, NEXT and CLOSE; the text beside the portrait,
    -- or wider without. The small window: BUTT002's bars, no text.
    local M = D.Message
    L.Message = entry(M, {
        place = function(win) X.Portrait(win, unpack(M.portrait)) end,
        text = function() end,
        fit = function(win)
            if textWindow(win) then
                local pic, t = hasPicture(win), M.text
                X.Size(win, t.width, t.height)
                X.Art(win, pic and t.picture or t.plain, t.palette)
                X.Image(win, win.prev, unpack(t.prev))
                X.Image(win, win.next, unpack(t.next))
                X.Image(win, win.close, unpack(t.close))
                X.Text(win.text, win, unpack(pic and t.withPicture or t.without))
                win.text:Show()
            else
                local s = M.small
                X.Size(win, s.width, s.height)
                X.Art(win, s.file)
                X.Image(win, win.prev, unpack(s.prev))
                X.Image(win, win.next, unpack(s.next))
                X.Image(win, win.close, unpack(s.close))
                win.text:Hide()
                smallWindow(win)
            end
        end,
    })

    -- The text window: the portrait's picture or the plain one; the prompt; the answers' list; OK, PREVIOUS, NEXT and
    -- CLOSE. The small window: the list and the buttons higher, no prompt.
    local Q = D.Question
    L.Question = entry(Q, {
        place = function(win) X.Portrait(win, unpack(Q.portrait)) end,
        text = function() end,
        fit = function(win)
            local text = textWindow(win)
            if text then
                local pic, t = hasPicture(win), Q.text
                X.Size(win, t.width, t.height)
                X.Art(win, pic and t.picture or t.plain, t.palette)
                X.List(win, win.list, unpack(t.list))
                X.Text(win.text, win, unpack(pic and t.withPicture or t.without))
                win.text:Show()
            else
                local s = Q.small
                X.Size(win, s.width, s.height)
                X.Art(win, s.file)
                X.List(win, win.list, unpack(s.list))
                win.text:Hide()
                smallWindow(win)
            end
            row(win, { win.ok, win.prev, win.next, win.close }, Q.buttons, text and Q.text.top or Q.small.top)
        end,
    })

    -- The text window: the portrait's picture or the plain one; the NPC's text; the prompt, the edit and the caption;
    -- OK, PREVIOUS, NEXT and CLOSE. The small window: the same prompt, edit and caption, and the four buttons on the
    -- window's rectangle, as 5.33 sets their rectangles only for the text window (7.5.2's TextDialog the same).
    --
    -- Input routing (wire): a press goes to the last control whose rectangle holds it (DialogPane_HitTestControls
    -- 0x004215F0), so in the small window a press on the prompt (5), the edit (6) or the caption (7) is theirs and any
    -- other press is CLOSE's (4). Here the buttons are one frame level apart in that order, under the edit and the
    -- texts' blockers (X.Blocker), as 7.x's look stacks them (the kit's X.Stacked). Changing the order or the rectangles changes which control
    -- a press reaches, so what the client sends.
    local T = D.TextReply
    L.TextReply = entry(T, {
        place = function(win)
            X.Portrait(win, unpack(T.portrait))
            X.Text(win.prompt, win, unpack(T.prompt))
            X.Edit(win.edit, win, unpack(T.edit))
            X.Text(win.caption, win, unpack(T.caption))
            win.x7over = X.Stacked(win, { win.ok, win.prev, win.next, win.close })
            X.Blocker(win.x7over, win, unpack(T.prompt))
            win.edit:SetParent(win.x7over)
            X.Blocker(win.x7over, win, unpack(T.caption))
        end,
        text = function() end,
        fit = function(win)
            local buttons = { win.ok, win.prev, win.next, win.close }
            if textWindow(win) then
                local pic, t = hasPicture(win), T.text
                X.Size(win, t.width, t.height)
                X.Art(win, pic and t.picture or t.plain, t.palette)
                X.Text(win.text, win, unpack(pic and t.withPicture or t.without))
                win.text:Show()
                row(win, buttons, T.buttons, t.top)
            else
                local s = T.small
                X.Size(win, s.width, s.height)
                X.Art(win, s.file)
                win.text:Hide()
                smallWindow(win)
                for i, b in ipairs(buttons) do X.Image(win, b, T.buttons.images[i], unpack(s.buttons)) end
            end
        end,
    })

    -- s6-interface-5x-b (round 8, s6-interface-5x's Y2): the Nexonclub registration (0x30 kind 9), 5.33's own window
    -- (NexonclubRegistrationDialog 0x0047C3C0, which 4a keeps as its classic layout of 0x0052F950): 375 x 286 on DLGNC.EPF
    -- in NPAL8.PAL; the prompt (40, 30)-(336, 153); the id (2) (126, 171)-(216, 183) and the masked password (3) (126,
    -- 191)-(216, 203), font 0 in 0x80 with no frame; OK (4, image 14) (77, 236)-(149, 252), CANCEL (5, image 22) (154,
    -- 236)-(226, 252), the web site's registration (6, image 32) (231, 236)-(303, 252).
    local N = D.Nexonclub
    L.Nexonclub = entry(N, {
        place = function(win)
            X.Art(win, unpack(N.art))
            X.Text(win.text, win, unpack(N.text))
            win.text:SetWordWrap(true)
            X.Edit(win.account, win, unpack(N.account))
            X.Edit(win.password, win, unpack(N.password))
            X.Image(win, win.ok, unpack(N.ok))
            X.Image(win, win.cancel, unpack(N.cancel))
            X.Image(win, win.create, unpack(N.create))
        end,
    })
end
