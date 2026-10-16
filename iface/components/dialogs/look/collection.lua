-- s6-modular-g (interfaces): the default look of the collection album (components/dialogs/collection.lua).

return function(L, P, W) -- W: the skin the look is drawn with (init.lua's Build)
    local K = TK.GetComponent("dialogs").kit

    -- D-33: the volume's title picture at the top left, the progress at the top right, six cards in two columns of
    -- three (each its picture, up to 95 square, then the name, the number, the label and the description), Previous,
    -- Close and Next along the bottom.
    L.Album = {
        width = 580, height = 440, button = 90, picture = 95,
        place = function(win)
            P.At(win.volume, win, 18, -10)
            win.progress:SetPoint("TOPRIGHT", win, "TOPRIGHT", -24, -24)
            P.Bottom(win.previous, win, -100, 14)
            P.Bottom(win.close, win, 0, 14)
            P.Bottom(win.nextButton, win, 100, 14)
        end,
        --- Card i, with its picture, name, number, label and description (the renderer fills them).
        card = function(win, i)
            local card = CreateFrame("Frame", nil, win)
            card:SetSize(255, 95)
            P.At(card, win, 18 + math.floor((i - 1) / 3) * 274, -62 - ((i - 1) % 3) * 104)
            local bg = card:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(card)
            bg:SetColorTexture(0, 0, 0, 0.3)
            card.pic = card:CreateTexture(nil, "ARTWORK")
            card.pic:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
            card.name = W.Label(card, "", 12, W.gold, "LEFT")
            card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 102, -6)
            card.number = W.Label(card, "", 12, W.white, "RIGHT")
            card.number:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -6)
            card.label = W.Label(card, "", 11, { 0.75, 0.75, 0.8 }, "RIGHT")
            card.label:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -30)
            card.desc = K.Block(card, 11)
            card.desc:SetPoint("TOPLEFT", card, "TOPLEFT", 102, -50)
            card.desc:SetWidth(146)
            return card
        end,
    }
end
