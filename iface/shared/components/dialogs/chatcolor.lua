-- s6-ui-chat: the chat colour dialog (ChattingColorPane "Chatting Color"; coverage rows G-37, C-14, O-45, D-65), opened
-- by the chat-mode menu's -Color- row. It is the dialog model's modal ChattingColorPane (OK, control 1, is Enter; Cancel,
-- control 2, is Esc), so while it is open every key and click is its own, as the original's (ChattingPane.cpp:1428-1429).
-- Its lists are the UI's: the six categories (Talk, Shout, Whisper, Group, Clan, System), each drawn in its colours, and
-- two grids of 80 swatches for the chosen category's text and outline colours (ChattingColorListPane 0x00482FB0). OK keeps
-- the six pairs (settings.toml chat.colors, Config::m_chatColorPairs); Cancel forgets them (OnControlCommand 0x00482B30).
-- New lines take the new colours; the lines in the log keep theirs, as each ChattingMessage keeps the colours it came with.
--
-- s6-modular-g (interfaces): the window's size, the category buttons', the swatches' and the captions' places are
-- the look's (C.look.ChatColor); this file keeps what the dialog does.
-- Wire: ChattingColorPane::OnControlCommand 0x00482B30: OK (1) and Cancel (2) go to the model, which closes the pane;
-- while it is open the model takes every key and click (modal), so none reaches the game. The colours are this
-- computer's settings: nothing of them is sent. Changing the indexes or the modality changes what the server sees.

local D = TK.GetComponent("dialogs")
local K = D.kit
local H = __tk

-- The swatches' palette indexes (ChattingPane.cpp:1549-1560), 16 to a row; the outline grid's first is 0, no outline.
local SWATCHES = {
    15, 128, 131, 133, 134, 137, 140, 143, 12, 14, 10, 2, 11, 9, 13, 5,
    40, 41, 42, 43, 44, 45, 46, 47, 222, 220, 218, 216, 214, 212, 210, 208,
    32, 33, 34, 35, 36, 37, 38, 39, 48, 49, 50, 51, 52, 53, 54, 55,
    161, 163, 165, 167, 169, 171, 173, 175, 56, 57, 58, 59, 60, 61, 62, 63,
    207, 205, 203, 201, 199, 197, 195, 193, 104, 105, 106, 107, 108, 109, 110, 111,
}

local CATEGORIES = TK.Chat.CATEGORIES -- s6-modular-g (round 17; s6-optimize's audit note, item 3): the chat's one list

local function rgb(index)
    local c = TK.Chat:PaletteRGB(index)
    return c or { 0.5, 0.5, 0.5 }
end

local R = { look = "ChatColor" }

--- One grid: the category's text colour (text) or its outline colour; its swatches made by the look (L.swatch).
local function grid(win, text)
    local g = {}
    for i, index in ipairs(SWATCHES) do
        if i == 1 and not text then index = 0 end
        local s = D.look.ChatColor.swatch(win)
        s.index = index
        s:SetScript("OnClick", function()
            win.colors[win.category * 2 - (text and 1 or 0)] = index
            R.paint(win)
        end)
        g[i] = s
    end
    return g
end

function R.build(view)
    local L = D.look.ChatColor
    local win = K.Window(L.width, L.height, "Chatting Color")
    win.categories = {}
    for i, name in ipairs(CATEGORIES) do
        local b = L.category(win, name)
        b:SetScript("OnClick", function()
            win.category = i
            R.paint(win)
        end)
        win.categories[i] = b
    end
    win.text = grid(win, true)
    win.outline = grid(win, false)
    win.ok = K.Button(win, 1, "OK", L.button)
    -- The model runs OK on a press and release on it, as this click is.
    win.ok:HookScript("OnClick", function() R.save(win) end)
    win.cancel = K.Button(win, 2, "Cancel", L.button)
    L.place(win)
    return win
end

function R.update(win, view)
    if win.opened then
        -- The constructor's copy of the pairs, Talk chosen (ChattingColorPane 0x004824E0).
        win.colors = TK.Chat:Colors()
        win.category = 1
    end
    R.paint(win)
end

function R.paint(win)
    local c = win.colors
    for i, b in ipairs(win.categories) do
        local fg = rgb(c[i * 2 - 1] or 143)
        b.label:SetTextColor(fg[1], fg[2], fg[3], 1)
        if i == win.category then b.bg:SetColorTexture(0.25, 0.4, 0.8, 0.5) else b.bg:SetColorTexture(0, 0, 0, 0.35) end
    end
    local fg, outline = c[win.category * 2 - 1], c[win.category * 2]
    for _, pair in ipairs({ { win.text, fg }, { win.outline, outline } }) do
        for _, s in ipairs(pair[1]) do
            if s.index == 0 then
                s.fill:SetColorTexture(0, 0, 0, 0)
            else
                local v = rgb(s.index)
                s.fill:SetColorTexture(v[1], v[2], v[3], 1)
            end
            -- The chosen swatch framed (DrawListEntry 0x004832C0), colour 0 ringed.
            if s.index == pair[2] then s.edge:SetColorTexture(1, 1, 1, 1)
            elseif s.index == 0 then s.edge:SetColorTexture(0.5, 0.5, 0.5, 1)
            else s.edge:SetColorTexture(0, 0, 0, 0) end
        end
    end
    -- s6-modular-g (interfaces, round 13): a look's own frames for the chosen category and swatches (7.x's: 4a's); drawing only
    local look = win.look or D.look
    if look.ChatColor.paint then look.ChatColor.paint(win) end
end

--- Before the model takes the key: Enter presses the focused button, else the default (OK); Space presses the focused
--- button (Dialog.PaneKey, DialogPane::HandleKeyOrTextEvent 0x0049E6E0). OK keeps the colours.
function R.key(win, key)
    local bare = TK.Util.BareKey(key)
    local focus = win.view and win.view.focus
    if (bare == "ENTER" and focus ~= 2) or (bare == "SPACE" and focus == 1) then R.save(win) end
end

--- OK: the six pairs into settings.toml; the chat's new lines take them.
function R.save(win)
    H:SetChatColors(table.concat(win.colors, ","))
    H:ClientSettingsSave()
end

D.renderers.ChattingColorPane = R
