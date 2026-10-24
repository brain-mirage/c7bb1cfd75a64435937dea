-- Small helpers shared by the framework and the components.

local U = {}
TK.Util = U

function U.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function U.Round(v, step)
    step = step or 1
    return math.floor(v / step + 0.5) * step
end

--- A deep copy of plain data (tables, strings, numbers, booleans).
function U.Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = U.Copy(x) end
    return t
end

--- Removes every key of t, keeping the table itself (others may hold it).
function U.Wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

--- An OnUpdate script that runs fn(frame, elapsed) on its first frame (or once first seconds have passed, when given),
--- then on the first frame at least period seconds after the last run (the time over the period is not carried over).
--- s6-optimize R66: for the drivers that look at something a few times a second, which each wrote this countdown out
--- before. s6-ui-core (round 101, the graphics plan's T11 step 2): while it is its frame's OnUpdate, it hands the
--- countdown to the host (Frame:SetUpdatePeriod), which then calls it only on the frames it is due, by the same rule in
--- the same arithmetic; wrapped by a hook (HookScript) or called some other way, it counts here as before (on from what
--- the host had left, when it was counting).
function U.Throttled(period, fn, first)
    local wait = first or 0
    local script
    script = function(frame, elapsed)
        local own = frame.GetScript ~= nil and frame:GetScript("OnUpdate") == script
        if own and frame.__updatePeriod == period then return fn(frame, elapsed) end -- the host found it due
        if frame.__updateLeftOf == script then -- the host counted until its OnUpdate was replaced (Frame:SetScript)
            wait, frame.__updateLeft, frame.__updateLeftOf = frame.__updateLeft, nil, nil
        end
        wait = wait - (elapsed or 0)
        local due = wait <= 0
        if due then wait = period end
        if own then frame:SetUpdatePeriod(period, wait) end
        if due then fn(frame, elapsed) end
    end
    return script
end

--- s6-ui-core (round 101, the graphics plan's T11 step 4): the frame's OnUpdate is called only while on. Off, the script
--- is set aside (the frame keeps it); on, it is put back. For an animation or a drag with nothing to do most of the time,
--- which turns itself off when done; not for a script with a period or a watch (SetScript drops them). Drawing only.
function U.Updating(frame, on)
    local script = frame:GetScript("OnUpdate")
    if on and not script and frame.__updatingAside then
        frame:SetScript("OnUpdate", frame.__updatingAside)
        frame.__updatingAside = nil
    elseif not on and script then
        frame.__updatingAside = script
        frame:SetScript("OnUpdate", nil)
    end
end

function U.FormatNumber(n)
    n = math.floor(n + 0.5)
    local s = tostring(math.abs(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then out = out:sub(2) end
    return (n < 0 and "-" or "") .. out
end

--- "SHIFT-1" -> "s1", "CTRL-NUMPAD3" -> "cN3": short key names for button corners.
function U.ShortKey(key)
    if not key or key == "" then return "" end
    local s = key
    s = s:gsub("ALT%-", "a"):gsub("CTRL%-", "c"):gsub("SHIFT%-", "s")
    s = s:gsub("NUMPAD", "N"):gsub("PAGEUP", "PU"):gsub("PAGEDOWN", "PD"):gsub("SPACE", "Sp")
    s = s:gsub("BACKSPACE", "Bs"):gsub("DELETE", "Del"):gsub("INSERT", "Ins"):gsub("HOME", "Hm")
    s = s:gsub("MULTIPLY", "*"):gsub("DIVIDE", "/"):gsub("PLUS", "+"):gsub("MINUS", "-"):gsub("DECIMAL", ".")
    return s
end

--- s6-input: a line's text with a caret at a UTF-16 offset (the logic's line counts in UTF-16 units).
function U.WithCaret(text, at)
    text = text or ""
    local byte = utf8.offset(text, (at or 0) + 1) or (#text + 1)
    return text:sub(1, byte - 1) .. "|" .. text:sub(byte)
end

--- A display string fitted to a pixel width with an ellipsis or supplied suffix, measured in the caller's font.
--- Shared from the original dialog kit so Modern and native text use the same whole-character cuts.
function U.FitText(text, max, width, suffix)
    if (width(text) or 0) <= max then return text end
    suffix = suffix or "..."
    local n = #text
    while n > 0 do
        local after = text:byte(n + 1)
        local whole = not (after and after >= 0x80 and after < 0xC0)
        if whole and (width(text:sub(1, n) .. suffix) or 0) <= max then break end
        n = n - 1
    end
    return text:sub(1, n) .. suffix
end

--- The key without its modifier prefixes: "ALT-SHIFT-Q" -> "Q", "SHIFT--" -> "-".
function U.BareKey(key)
    local changed = true
    while changed do
        changed = false
        for _, m in ipairs({ "ALT-", "CTRL-", "SHIFT-" }) do
            if #key > #m and key:sub(1, #m) == m then
                key = key:sub(#m + 1)
                changed = true
            end
        end
    end
    return key
end

--- A frame's or region's rectangle in UIParent units (left, bottom, width, height), or nil.
function U.RootRect(frame)
    local l, b, w, h = frame:GetRect()
    if not l then return nil end
    local s = (frame.GetEffectiveScale and frame or frame:GetParent()):GetEffectiveScale()
    return l * s, b * s, w * s, h * s
end

--- The cursor in UIParent units. GetCursorPosition is in screen pixels; UIParent units are pixels divided by
--- the global UI scale (the canvas's scale). Frames' effective scales do not include the global UI scale.
function U.CursorRoot()
    local x, y = GetCursorPosition()
    local s = TK.UIScale()
    return x / s, y / s
end

--- Whether the frame under the pointer (GetMouseFocus) is one of the given frames or inside one: the test of a menu
--- that a press anywhere else closes. It only looks. s6-optimize R62: the context menu, Modern's chat-mode menu and
--- 7.x's say-mode menu each walked the parents themselves before.
function U.MouseWithin(...)
    local focus = GetMouseFocus()
    while focus do
        for i = 1, select("#", ...) do
            if focus == select(i, ...) then return true end
        end
        focus = focus:GetParent()
    end
    return false
end

local pointNames = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
U.Points = pointNames

--- The screen point nearest a rectangle, by thirds of the screen, and the offset from it to the same point of
--- the rectangle, in the frame's units. The Lua twin of TK.Core's AnchorSolver.NearestScreenPoint.
function U.NearestScreenPoint(l, b, w, h, scale)
    local sw, sh = GetScreenWidth(), GetScreenHeight()
    local cx, cy = l + w / 2, b + h / 2
    local col = cx < sw / 3 and 0 or (cx > sw * 2 / 3 and 2 or 1)
    local row = cy > sh * 2 / 3 and 0 or (cy < sh / 3 and 2 or 1)
    local fx, fy = col * 0.5, 1 - row * 0.5
    local px, py = l + fx * w, b + fy * h
    local sx, sy = fx * sw, fy * sh
    return pointNames[row * 3 + col + 1], (px - sx) / scale, (py - sy) / scale
end
