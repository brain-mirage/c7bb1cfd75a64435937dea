-- 5.33 music control composition. The shared X8 renderer supplies the actual controls
-- and their current states; this skin only places them and paints native sprites/text.
-- No setting, audio call, focus change, input handler or packet is implemented here.
local S = require("interfaces.5x.skin")
local Layout = require("interfaces.5x.dialogs.musiclayout")
local M = {}
local VOLUMES, GROUPS = { 2, 4 }, { 5, 9, 10 }

-- A texture cache belongs to this dialog, including pooled windows. Native sprite
-- origins stay mask-crop-relative as S.Picture defines them; no art is stretched.
local function picture(win, key, file, frame, palette, x, y)
    win.musicArt = win.musicArt or {}
    local t = S.Picture(win, win.musicArt[key], file, frame, palette, x, y)
    win.musicArt[key] = t
    return t
end

-- Tiled middle regions exclude the slider thumb, as native paint 0x0041A100 does.
-- A partial final tile clips its UVs instead of squeezing thirteen pixels into it.
local function tiled(win, key, file, frame, palette, l, t, r, b, size)
    local n = 0
    for y = t, b - 1, size do
        for x = l, r - 1, size do
            n = n + 1
            local tex = picture(win, key .. n, file, frame, palette, x, y)
            local art, w, h = S.Image(file, frame, palette)
            if art then
                local ox, oy = TK.Art.Origin(art)
                local cw, ch = math.max(0, math.min(w, r - x - ox)), math.max(0, math.min(h, b - y - oy))
                tex:SetSize(cw, ch)
                tex:SetTexCoord(0, cw / w, 0, ch / h)
            end
        end
    end
end

-- Native disabled controls retain their picture beneath the white half-strength
-- fill (Slider 0x0041A100, popup 0x0041B100). Radio options instead use their
-- disabled frames 2/3 (native RadioGroup::DrawItem 0x00419DA0).
local function disabled(win, id, enabled)
    if enabled then return end
    win.musicArt = win.musicArt or {}
    local key = "disabled" .. id
    local tex = win.musicArt[key] or win:CreateTexture(nil, "OVERLAY")
    win.musicArt[key] = tex
    local r = Layout.rects[id]
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", win, "TOPLEFT", r[1], -r[2])
    tex:SetSize(r[3] - r[1], r[4] - r[2])
    tex:SetColorTexture(S.Colour(0x8F))
    tex:SetAlpha(0.5)
    tex:Show()
end

-- Focus ownership stays shared. Native slider/popup paint adds this one-pixel
-- black frame only when that owner supplies focused=true on an enabled control.
local function focus(win, id, state)
    if not state.enabled or not state.focused then return end
    local r = Layout.rects[id]
    for i, edge in ipairs({ { r[1], r[2], r[3], r[2] + 1 }, { r[1], r[4] - 1, r[3], r[4] },
        { r[1], r[2], r[1] + 1, r[4] }, { r[3] - 1, r[2], r[3], r[4] } }) do
        local key = "focus" .. id .. "_" .. i
        local tex = win.musicArt[key] or win:CreateTexture(nil, "OVERLAY")
        win.musicArt[key] = tex
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", win, "TOPLEFT", edge[1], -edge[2])
        tex:SetSize(edge[3] - edge[1], edge[4] - edge[2])
        tex:SetColorTexture(S.Colour(0x80))
        tex:Show()
    end
end

-- controls[id] is a shared control frame, or an array of radio-choice frames.
-- The folder (6) is the shared font string. CD text is supplied by state, so this
-- look never reaches into a shared dropdown's private label/widget structure.
-- The existing shared renderer keeps ownership of their handlers and value changes.
function M.Place(X, win, controls)
    for _, id in ipairs({ 2, 4, 8 }) do
        local parent = controls[id]:GetParent()
        if parent ~= win then
            -- The contract supplies slider tracks / the dropdown button. Their
            -- shared containers hold labels and numeric fields; native art hides
            -- that presentation and gives the slider's own math its native width.
            X.Rect(parent, win, table.unpack(Layout.rects[id]))
            parent:SetAlpha(0)
        end
        X.Rect(controls[id], win, table.unpack(Layout.rects[id]))
        controls[id]:SetAlpha(0) -- input surface remains; native art is painted on the window
    end
    local folder = controls[6]:GetParent()
    if folder ~= win then
        X.Rect(folder, win, table.unpack(Layout.rects[6]))
        folder:SetAlpha(0)
    end
    controls[6]:SetAlpha(0)
    if not win.musicFolderClip then
        -- A font string's width alone does not clip an unwrapped path. Use the
        -- existing ScrollFrame clipping seam, as the native TextControlPane clips
        -- control 6 to its rectangle. Keep the complete shared path and input
        -- surface; this child only bounds the glyphs before the Browse button.
        local clip = CreateFrame("ScrollFrame", nil, win)
        local content = CreateFrame("Frame", nil, clip)
        clip:SetScrollChild(content)
        win.musicFolderClip, win.musicFolderContent = clip, content
        win.musicFolderText = content:CreateFontString(nil, "ARTWORK")
    end
    local r = Layout.rects[6]
    X.Rect(win.musicFolderClip, win, table.unpack(r))
    win.musicFolderContent:SetSize(r[3] - r[1], r[4] - r[2])
    X.Text(win.musicFolderText, win.musicFolderContent, 0, 0, r[3] - r[1], r[4] - r[2])
    win.musicFolderText:SetHeight(Layout.rects[6][4] - Layout.rects[6][2])
    win.musicFolderText:SetWordWrap(false)
    for _, id in ipairs(GROUPS) do
        local parent = controls[id][1]:GetParent()
        if parent ~= win then
            -- Native RadioGroup bounds belong to this look too. Keep each shared
            -- group's input/focus container around its already-shared choices.
            X.Rect(parent, win, table.unpack(Layout.rects[id]))
            parent:SetAlpha(0)
        end
        for i, btn in ipairs(controls[id]) do
            X.Rect(btn, win, table.unpack(Layout.options[id][i]))
            btn:SetAlpha(0)
        end
    end
end

-- state[id] carries value (volume or zero-based radio selection) and enabled;
-- a slider's optional pressed value is left/right/thumb/before/after. These are
-- presentation inputs supplied by the shared renderer, not another music model.
-- state[8].text is the displayed CD choice (empty when there are no drives).
function M.Paint(win, controls, state)
    for _, tex in pairs(win.musicArt or {}) do tex:Hide() end
    for _, id in ipairs(VOLUMES) do
        local r, s, art = Layout.rects[id], state[id], Layout.slider
        local x = r[1] + Layout.ThumbLeft(s.value)
        picture(win, "left" .. id, art.file, s.pressed == "left" and art.leftPressed or art.left, art.palette, r[1], r[2])
        picture(win, "right" .. id, art.file, s.pressed == "right" and art.rightPressed or art.right, art.palette, r[3] - art.cap, r[2])
        if s.enabled then
            tiled(win, "before" .. id, art.file, s.pressed == "before" and art.trackPressed or art.track, art.palette,
                r[1] + art.cap, r[2], x, r[4], art.cap)
            tiled(win, "after" .. id, art.file, s.pressed == "after" and art.trackPressed or art.track, art.palette,
                x + art.cap, r[2], r[3] - art.cap, r[4], art.cap)
            picture(win, "thumb" .. id, art.file, s.pressed == "thumb" and art.thumbPressed or art.thumb, art.palette, x, r[2])
        else
            tiled(win, "disabledTrack" .. id, art.file, art.trackPressed, art.palette, r[1] + art.cap, r[2], r[3] - art.cap, r[4], art.cap)
        end
        disabled(win, id, s.enabled)
        focus(win, id, s)
    end
    for _, id in ipairs(GROUPS) do
        for i, r in ipairs(Layout.options[id]) do
            local frame = (state[id].value == i - 1 and 1 or 0) + (state[id].enabled and 0 or 2)
            picture(win, "radio" .. id .. "_" .. i, "RADIOBUT.EPF", frame,
                "NPAL8.PAL", r[1], math.floor((r[2] + r[4]) / 2) - 5)
        end
    end
    win.musicFolderText:SetText(state[6].text or controls[6]:GetText())
    win.musicFolderText:SetTextColor(S.Colour(state[6].enabled and Layout.folder.active or Layout.folder.disabled))
    local r, p = Layout.rects[8], Layout.popup
    picture(win, "popupLeft", p.file, p.left, p.palette, r[1], r[2])
    tiled(win, "popupMiddle", p.file, p.middle, p.palette, r[1] + p.cap, r[2], r[3] - p.cap, r[4], p.cap)
    picture(win, "popupRight", p.file, p.right, p.palette, r[3] - p.cap, r[2])
    win.musicCdText = win.musicCdText or win:CreateFontString(nil, "OVERLAY")
    S.Text(win.musicCdText, p.text)
    win.musicCdText:SetText(state[8].text)
    win.musicCdText:ClearAllPoints()
    win.musicCdText:SetPoint("TOPLEFT", win, "TOPLEFT", r[1] + 1, -(r[4] - 14))
    win.musicCdText:SetSize(r[3] - r[1] - p.cap - 1, 12)
    win.musicCdText:SetJustifyH("LEFT")
    win.musicCdText:SetJustifyV("TOP")
    win.musicCdText:SetWordWrap(false)
    disabled(win, 8, state[8].enabled)
    focus(win, 8, state[8])
end

return M
