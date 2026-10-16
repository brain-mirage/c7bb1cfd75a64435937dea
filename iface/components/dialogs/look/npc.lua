-- s6-modular-g (interfaces): the default look of the NPC dialogs (components/dialogs/npc.lua).

-- W: the skin the look is drawn with (init.lua's Build), one alias for the whole file: Modern's skin in Modern's look,
-- so its capsule and labels take Modern's colours (s6-devtools r6, merged in s6-characters round 48)
return function(L, P, W)
    --- The text block from the window's top, right of the portrait (x: how far right the text starts, 0 without one).
    local function textAt(win, x, top) P.Across(win.text, win, 20 + x, 20, top, true) end

    -- D-01, D-02 (MessageDialog, MessageDialogLarger): the text, then Prev, Next and Close from the bottom right.
    L.Message = {
        width = 440, height = 230, button = 90,
        place = function(win)
            textAt(win, 0, -36)
            P.Row(win, { win.close, win.next, win.prev }, 16, 14, 8)
        end,
        text = function(win, x) textAt(win, x, -36) end,
        -- The window as tall as its text (or the portrait), at least 160.
        fit = function(win, ph) win:SetHeight(math.max(160, math.max(win.text:GetStringHeight(), ph) + 96)) end,
    }

    -- D-03, D-04 (MenuQuestionDialog, MenuQuestionDialogLarger): the prompt, the answers' list under it, OK, Prev, Next
    -- and Close from the bottom right.
    L.Question = {
        width = 440, height = 320, button = 80, listWidth = 380, listHeight = 150,
        place = function(win)
            textAt(win, 0, -36)
            P.Row(win, { win.close, win.next, win.prev, win.ok }, 16, 14, 8)
        end,
        text = function(win, x) textAt(win, x, -36) end,
        -- The list under the prompt (or the portrait), and the window round both.
        fit = function(win, ph)
            local th = math.max(win.text:GetStringHeight(), ph)
            win.list.sf:ClearAllPoints()
            P.At(win.list.sf, win, 26, -44 - th)
            win:SetHeight(th + 150 + 96)
        end,
    }

    -- D-05 (TextDialog): the message, the prompt with the edit under it and its caption on its right; OK, Prev, Next and
    -- Close from the bottom right.
    L.TextReply = {
        width = 440, height = 250, button = 80, editWidth = 300, editHeight = 24,
        place = function(win)
            textAt(win, 0, -36)
            P.Row(win, { win.close, win.next, win.prev, win.ok }, 16, 14, 8)
        end,
        text = function(win, x) textAt(win, x, -36) end,
        -- The prompt under the message (none: at the top), the edit under it, the caption beside it; the window round them.
        fit = function(win, x, ph)
            local th = win.text:GetText() ~= "" and win.text:GetStringHeight() + 12 or 0
            win.prompt:ClearAllPoints()
            P.At(win.prompt, win, 20 + x, -36 - th)
            th = math.max(th, ph - 60)
            -- The portrait shares this row with the edit and the full caption. Reserve the caption's measured
            -- width and the existing 20-unit right inset; without a portrait the edit keeps its usual width.
            -- Measure before clearing the edit's anchors: layout queries must not briefly hide its focused control.
            -- Keep 4a TextDialog 0x00553180/0x00553350's control 6/field0 text; changing focus changes what the server sees.
            win.edit:SetWidth(math.min(L.TextReply.editWidth, win:GetWidth() - 40 - x - 8 - win.caption:GetStringWidth()))
            win.edit:ClearAllPoints()
            win.edit:SetPoint("TOPLEFT", win.prompt, "BOTTOMLEFT", 0, -6)
            win.caption:ClearAllPoints()
            win.caption:SetPoint("LEFT", win.edit, "RIGHT", 8, 0)
            win:SetHeight(th + 150)
        end,
    }

    -- D-06 (HeadSelectDialog 0x00551520): 4a's own layer, 374 x 316: the preview (37 x 55 on black at 36, 40), the heads
    -- on a 5 x 2 grid of 41 x 54 buttons from (58, 113), 54 across and 64 down, the chosen one's capsule behind it
    -- (CAPSULE.EPF frame 0 in NPAL3.PAL, centred on the button; a gold box without the packs), the page buttons under the
    -- grid, OK and CLOSE from the bottom right.
    L.Heads = {
        width = 374, height = 316, button = 80, head = { 41, 54 }, page = 30,
        place = function(win)
            win.preview:SetSize(37, 55)
            P.At(win.preview, win, 36, -40)
            P.Across(win.text, win, 90, 20, -40)
            for i = 0, 9 do
                local b = win.heads[i]
                P.At(b, win, 58 + i % 5 * 54, -(113 + math.floor(i / 5) * 64))
                b.capsule = b:CreateTexture(nil, "BORDER")
                b.capsule:SetPoint("CENTER", b, "CENTER", 0, 0)
                local capsule, cw, ch = TK.Art.Image("CAPSULE.EPF", 0, "NPAL3.PAL")
                if capsule then
                    b.capsule:SetTexture(capsule)
                    b.capsule:SetSize(cw, ch)
                else
                    b.capsule:SetSize(47, 60)
                    b.capsule:SetColorTexture(W.gold[1], W.gold[2], W.gold[3], 0.45)
                end
            end
            P.At(win.left, win, 58, -245)
            win.right:SetPoint("LEFT", win.left, "RIGHT", 6, 0)
            P.Row(win, { win.close, win.ok }, 16, 14, 8)
        end,
    }

    -- D-07 (NexonclubRegistrationDialog): the text, the account and password edits with their labels, OK and CANCEL from
    -- the bottom right, CREATE at the bottom left.
    L.Nexonclub = {
        width = 380, height = 200, title = "Nexonclub", button = 90, editWidth = 200, editHeight = 24,
        place = function(win)
            P.Across(win.text, win, 20, 20, -36)
            local a = W.Label(win, "Account", 13, W.gold, "LEFT")
            P.At(a, win, 20, -80)
            win.account:SetPoint("LEFT", a, "LEFT", 90, 0)
            local p = W.Label(win, "Password", 13, W.gold, "LEFT")
            p:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -16)
            win.password:SetPoint("LEFT", p, "LEFT", 90, 0)
            P.Row(win, { win.cancel, win.ok }, 16, 14, 8)
            win.create:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 16, 14)
        end,
    }
end
