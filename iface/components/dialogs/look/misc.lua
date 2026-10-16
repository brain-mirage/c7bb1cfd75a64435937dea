-- s6-modular-g (interfaces): the default look of the music dialog, the papers and the profile
-- (components/dialogs/misc.lua; the world map and the photo place themselves there).

return function(L, P, W) -- W: the skin the look is drawn with (init.lua's Build)

    -- r66: the existing Modern music window now places the complete shared controls. Native looks replace
    -- placeControls only; they keep all state/audio/input in the renderer and the original model.
    L.Music = {
        width = 360, height = 570, button = 90, buttonHeight = 24, switch = 60, frequency = 66, play = 36,
        placeControls = function(win)
            P.At(win.effectsVolume, win, 20, -72)
            P.At(win.musicVolume, win, 20, -156)
            P.At(win.source, win, 20, -215)
            P.At(win.folder, win, 20, -270)
            P.At(win.cd, win, 220, -286)
            P.At(win.order, win, 20, -345)
            P.At(win.repeatMode, win, 20, -405)
        end,
        place = function(win)
            local e = W.Label(win, "Sound effects", 13, W.gold, "LEFT")
            P.At(e, win, 20, -44)
            win.on:SetPoint("LEFT", e, "LEFT", 120, 0)
            win.off:SetPoint("LEFT", win.on, "RIGHT", 6, 0)
            local f = W.Label(win, "Frequency", 13, W.gold, "LEFT")
            P.At(f, win, 20, -130)
            for i, b in ipairs(win.freq) do b:SetPoint("LEFT", f, "LEFT", 105 + (i - 1) * 70, 0) end
            P.At(win.browse, win, 20, -310)
            P.At(win.prev, win, 20, -470)
            win.pause:SetPoint("LEFT", win.prev, "RIGHT", 4, 0)
            win.next:SetPoint("LEFT", win.pause, "RIGHT", 4, 0)
            P.Bottom(win.ok, win, 0, 14)
        end,
    }

    -- The already-declared Browse dialog. This default is usable in every interface until its native look lands.
    L.FolderSelect = {
        width = 380, height = 360,
        -- Keep the transparent picker beside its parent when the screen has room, so its title/Drive caption
        -- do not overprint the parent's frequency/volume captions. This changes drawing placement only.
        open = function(win)
            local parent = TK.Dialogs.Find("MusicControlDialog")
            local l, b, w, h
            if parent then l, b, w, h = TK.Util.RootRect(parent) end
            win:ClearAllPoints()
            if l then
                local pw = win:GetWidth()
                local x = l + w + 12
                if x + pw > GetScreenWidth() - 10 then x = l - pw - 12 end
                if x >= 10 then
                    win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, math.min(b + h, GetScreenHeight() - 10))
                else win:SetPoint("CENTER", UIParent, "CENTER", 12, 48) end
            else win:SetPoint("CENTER", UIParent, "CENTER", 12, 48) end
            TK.FitToScreen(win, 10)
        end,
        place = function(win)
            P.At(win.drives, win, 20, -38)
            P.At(win.up, win, 298, -56)
            P.At(win.path, win, 20, -90) win.path:SetSize(330, 38)
            P.At(win.list, win, 20, -134) win.list:SetSize(330, 168)
            P.At(win.choose, win, 176, -316)
            P.At(win.cancel, win, 276, -316)
        end,
    }

    -- D-68, D-69: the paper's edit (writable) or its text, the same place; "Esc: done" at the bottom right.
    L.Paper = {
        width = 420, height = 360, editWidth = 380, editHeight = 270,
        place = function(win)
            P.At(win.edit, win, 20, -38)
            P.At(win.text, win, 24, -42)
            win.text:SetWidth(372)
            local hint = W.Label(win, "Esc: done", 12, W.grey, "RIGHT")
            hint:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -18, 16)
        end,
        -- Same body width and placement, now clipped at the paper's existing edit height.
        -- The common viewport supplies local wheel/thumb input; no native art or geometry is imported.
        fit = function(win, c)
            if c.writable then return win:PlainPaperText() end
            local sf = win:ReadOnlyBody()
            P.At(sf, win, 24, -42)
            sf:SetSize(372, L.Paper.editHeight)
            P.At(win.text, sf.content, 0, 0)
            win.text:SetWidth(372)
            sf.content:SetWidth(372)
        end,
    }

    -- D-62: the profile's text, OK at the bottom. s6-ui-core (build 41; the owner: "add a button to the profile page to
    -- import your own [picture]"): the window has the player's own picture at its left, with Import and Remove
    -- (profilepicture.lua beside this file; the import itself is core/profilepicture.lua's). It is shown on this client
    -- only; the dialog's field, its OK and what OK sends are unchanged (the picture is not the face 0x4F carries).
    L.Profile = {
        width = 540, height = 300, button = 90, editWidth = 368, editHeight = 200,
        place = function(win)
            win.picture = require("components.dialogs.look.profilepicture")(win, W)
            P.At(win.picture, win, 20, -38)
            P.At(win.edit, win, 150, -38)
            P.Bottom(win.ok, win, 0, 14)
        end,
    }
end
