-- Native 5.33 MusicControlDialog layout (constructor 0x00478720). The shared X8
-- renderer owns controls, selections, enabled rules and audio; this is art data only.
-- IDs are the shared original control IDs. Moving a rectangle changes where a press
-- lands; changing an ID or binding instead changes what 4a 0x00529790 sends.
local M = {
    width = 407, height = 410,
    background = { file = "DLGSCNTL.EPF", palette = "NPAL8.PAL", frame = 0 },
    rects = {
        [1] = { 109, 97, 313, 108 }, [2] = { 109, 112, 301, 125 },
        [3] = { 109, 159, 333, 170 }, [4] = { 109, 175, 301, 188 },
        [5] = { 88, 202, 200, 263 }, [6] = { 87, 234, 261, 246 },
        [7] = { 261, 232, 333, 248 }, [8] = { 234, 250, 308, 266 },
        [9] = { 88, 279, 301, 290 }, [10] = { 88, 294, 301, 305 },
        [11] = { 94, 314, 166, 330 }, [12] = { 168, 314, 240, 330 },
        [13] = { 242, 314, 314, 330 }, [14] = { 168, 360, 240, 376 },
    },
    options = {
        [1] = { { 109, 97, 154, 108 }, { 260, 97, 305, 108 } },
        [3] = { { 109, 159, 154, 170 }, { 182, 159, 227, 170 }, { 250, 159, 295, 170 } },
        [5] = { { 88, 202, 198, 213 }, { 88, 217, 198, 228 }, { 88, 252, 198, 263 } },
        [9] = { { 88, 279, 168, 290 }, { 205, 279, 285, 290 } },
        [10] = { { 88, 294, 168, 305 }, { 205, 294, 285, 305 } },
    },
    buttons = { [7] = 50, [11] = 46, [12] = 48, [13] = 47, [14] = 14 },
    slider = {
        file = "SCRL001.EPF", palette = "SCRL001.PAL", cap = 13,
        left = 0, right = 1, leftPressed = 4, rightPressed = 5,
        thumb = 8, thumbPressed = 9, track = 11, trackPressed = 10,
    },
    popup = { file = "POPUPMNU.EPF", palette = "NPAL8.PAL", left = 0, middle = 1, right = 2, cap = 16, text = 0x25 },
    folder = { active = 0x8F, disabled = 0x80 },
}

-- Native GetPartRect 0x0041A6F0: only the thumb's drawing coordinate. The shared
-- slider owns values, hit testing, keys, dragging and notification; no action runs here.
function M.ThumbLeft(value)
    return M.slider.cap + math.floor(value * (192 - 3 * M.slider.cap) / 100)
end

return M
