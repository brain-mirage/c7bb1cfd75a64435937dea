-- s6-ui-core (round 171, steer 70b1e9b2, the owner 2026-11-17): 7.x's look of the minimap
-- (shared/components/dialogs/misc.lua's MiniMapDialog), the original's window (MiniMapDialog 0x00450CA0; Source-5's
-- class pages MiniMapDialog, its GetControlLayout, BuildControls and OnTimer, and MiniMapSymbolControlPane). Drawing
-- only, but for where each control's press lands (its rectangle): the controls, their indexes, the keys and what is
-- sent are the renderer's and the model's, the same in every look. Its places, pictures and texts are minimap.xml's.
--
-- The window: 768 x 768 at (40, 0) on the 1024 x 768 screen, MMAPBACK.EPF as its picture; the title plate (MNTITLE.EPF)
-- with the map's name centred on it; the NPC (2) and Portal (4) check boxes (ONOFFBUT.EPF, frame 1 checked) with their
-- texts (3, 5); the close button (6); "X : " and "Y : " (7, 9) with the cell under the pointer (8, 10); our map picture
-- in the 662 x 662 square at (53, 53), where the original's .mnm picture is, framed 2 pixels outside it in colour 0x80
-- (RectangleControlPane). The marks as MiniMapSymbolControlPane draws them: each picture's whole frame centred on its
-- point; the player's MNPLAYER.EPF (frames 0-4) and the NPCs' MNSYMBOL.EPF 4 with the name above (centred on the point
-- less MNSYMBOL frame 3's height; the player's at 0.7); the portals' MNSYMBOL.EPF 5 (with lines) or 3.

local unpack = table.unpack
local entry = require("shared.original.entry")
local S = require("interfaces.7x.skin")
local D = TK.Xml.Data("minimap.xml")

return function(L, X)
    local M = D.MiniMap
    local Y, P, C = M.symbol, M.player, M.check

    --- A check box of 4a's (CheckBoxControlPane) over the kit's check: its rectangle takes the press, ONOFFBUT.EPF's
    --- frame 0 (frame 1 checked) at its top left; its text is a control of its own (3, 5), drawn apart.
    local function check(win, box, rect)
        X.Rect(box, win, unpack(rect))
        for i, tex in ipairs({ box.box, box.check }) do
            local key, w, h = TK.Art.Image(C.file, i - 1, C.palette)
            if key then
                local ox, oy = TK.Art.Origin(key)
                tex:SetTexture(key)
                tex:SetSize(w, h)
                tex:ClearAllPoints()
                tex:SetPoint("TOPLEFT", box, "TOPLEFT", ox, -oy)
            end
        end
        box.hl:SetAlpha(0)
        box.label:Hide()
    end

    L.MiniMap = entry(M, {
        map = M.map,
        player = M.player,
        --- 4a's window at (40, 0): centred on (424, 384), not moved by the slot's clamps (L.Place)
        centre = function() return M.centreX, M.centreY, false end,
        --- The window's fixed parts at their places (once a window: a window used again keeps them).
        place = function(win)
            X.Art(win, unpack(M.art))
            win.x7plate = S.Picture(win, win.x7plate, M.plate.file, 0, M.plate.palette, M.plate.x, M.plate.y)
            S.Text(win.mapName)
            win.mapName:ClearAllPoints()
            win.mapName:SetPoint("CENTER", win, "TOPLEFT", M.title[1], -M.title[2])
            check(win, win.npc, M.npc)
            check(win, win.portal, M.portal)
            win.x7labels = win.x7labels or {}
            for i, o in ipairs(M.labels) do
                local fs = win.x7labels[i] or TK.UI.Label(win, "", 12)
                win.x7labels[i] = fs
                X.Text(fs, win, o.at[1], o.at[2], o.at[1] + 40, o.at[2] + 13)
                fs:SetText(o.text)
            end
            X.Text(win.cellX, win, unpack(M.cellX))
            X.Text(win.cellY, win, unpack(M.cellY))
            X.Image(win, win.close, unpack(M.close))
            win.x7frame = win.x7frame or {}
            for i = 1, 4 do
                win.x7frame[i] = win.x7frame[i] or S.Fill(win:CreateTexture(nil, "ARTWORK"), S.TEXT)
                win.x7frame[i]:Hide()
            end
        end,
        --- The map's part of the picture on (l, t)-(r, b) of the window, its frame 2 pixels outside it.
        picture = function(win, l, t, r, b)
            X.Rect(win.map, win, l, t, r, b)
            local f, edges = M.map.frame, win.x7frame
            local sides = { { l - f, t - f, r + f, t }, { l - f, b, r + f, b + f },
                { l - f, t, l, b }, { r, t, r + f, b } }
            for i, s in ipairs(sides) do
                X.Rect(edges[i], win, unpack(s))
                edges[i]:Show()
            end
        end,
        --- A mark of kind ("player": in frame <frame>; "npc", "portal", "portalLines") centred on (x, y) of the window,
        --- moved inside bounds (left, top, right, bottom) when given, with its name above it when one is given;
        --- returns its picture's rectangle (left, top, right, bottom).
        mark = function(win, pin, kind, frame, x, y, name, bounds)
            local file, palette, n = Y.file, Y.palette, Y[kind]
            if kind == "player" then file, palette, n = P.file, P.palette, frame end
            local key, w, h = TK.Art.Image(file, n, palette)
            local ok, fw, fh = false, w, h
            if key then ok, fw, fh = __tk:GetArtFrameSize(key) end
            if not ok then fw, fh = w or 0, h or 0 end
            local l, t = math.floor(x - fw / 2), math.floor(y - fh / 2)
            if bounds then
                l = math.max(bounds[1], math.min(l, bounds[3] - fw))
                t = math.max(bounds[2], math.min(t, bounds[4] - fh))
                x, y = l + fw / 2, t + fh / 2
            end
            -- s6-ui-core (round 172, steer f0ee3154): the player's mark comes again every 100 ms for its next frame
            -- (misc.lua's minimapTick); each part is set only when it changed: the picture at each frame, the place
            -- and the name when they move. A pin the list hides forgets what it showed (pin.drawn). Drawing only.
            local d = pin.drawn
            if not d then
                d = { key = false }
                pin.drawn = d
            end
            if d.key ~= key then
                d.key = key
                pin.tex:SetShown(key ~= nil)
                if key then
                    pin.tex:SetTexture(key)
                    pin.tex:SetSize(w, h)
                end
            end
            if key then
                local ox, oy = TK.Art.Origin(key)
                local px, py = l + ox, -(t + oy)
                if d.px ~= px or d.py ~= py then
                    d.px, d.py = px, py
                    pin.tex:ClearAllPoints()
                    pin.tex:SetPoint("TOPLEFT", win, "TOPLEFT", px, py)
                end
            end
            if d.name ~= name or d.x ~= x or d.y ~= y or d.kind ~= kind then
                d.name, d.x, d.y, d.kind = name, x, y, kind
                pin.label:SetShown(name ~= nil)
                if name then
                    local _, _, above = TK.Art.Image(Y.file, Y.label, Y.palette)
                    S.Text(pin.label)
                    pin.label:SetText(name)
                    pin.label:SetAlpha(kind == "player" and P.alpha or 1)
                    pin.label:ClearAllPoints()
                    pin.label:SetPoint("CENTER", win, "TOPLEFT", x, -(y - (above or 0)))
                end
            end
            return l, t, l + fw, t + fh
        end,
    })
end
