-- Native 5.33 MusicControlDialog layout (constructor 0x00478720). The shared X8
-- renderer owns controls, selections, enabled rules and audio; this is art data only.
-- IDs are the shared original control IDs. Moving a rectangle changes where a press
-- lands; changing an ID or binding instead changes what 4a 0x00529790 sends.
--
-- s6-ui-core (round 85): the XML twin's; the layout is musiclayout.xml's (core/xml.md), made here into the table the
-- original's file is (the options and the buttons by their control's id).
local D = TK.Xml.Data("musiclayout.xml")
local X = D.MUSIC

local M = {
    width = X.width, height = X.height,
    background = X.background,
    rects = X.rects,
    options = {},
    buttons = {},
    slider = X.slider,
    popup = X.popup,
    folder = X.folder,
}
for _, group in ipairs(X.options) do
    local list = {}
    for i, r in ipairs(group) do list[i] = r end
    M.options[group.id] = list
end
for _, b in ipairs(X.buttons) do M.buttons[b.id] = b.image end

-- Native GetPartRect 0x0041A6F0: only the thumb's drawing coordinate. The shared
-- slider owns values, hit testing, keys, dragging and notification; no action runs here.
function M.ThumbLeft(value)
    return M.slider.cap + math.floor(value * (D.THUMB.span - 3 * M.slider.cap) / 100)
end

return M
