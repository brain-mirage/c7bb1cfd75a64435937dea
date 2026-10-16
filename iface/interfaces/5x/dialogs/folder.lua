-- Native folder presentation over the shared X8 enumeration/navigation renderer.
-- 5.33 constructor 0x0042EF20: 300x316, drive (16,16)-(66,32), viewport
-- (16,32)-(284,282), image 14/22 buttons. The existing geometry topic note
-- records these rectangles. Up/path expose the shared flat-list navigation;
-- this look does not add an expandable tree or replace shared 7.5.2 commands.
local S = require("interfaces.5x.skin")
local Bar = require("interfaces.5x.scrollbar")

return function(L, X)
    L.FolderSelect = {
        width = 300, height = 316,
        place = function(win)
            local frame = X.DIALOG_FRAME
            X.Frame(win, 300, 316, frame.file, frame.palette, frame.tile)
            -- The native window owns its art; shared Choose/Cancel IDs and matched
            -- releases remain FolderSelectDialog 0x004B1920's. Changing those
            -- routes changes what the server sees through C12 0x0057A890.
            X.Rect(win.drives, win, 16, 16, 66, 32)
            win.drives.title:Hide()
            X.Rect(win.drives.button, win, 16, 16, 66, 32)
            win.drives.button:SetBackdrop(nil)
            win.drives.button:SetAlpha(0) -- shared popup input; native field painted below
            X.Text(win.drives.text, win, 20, 17, 50, 31)
            win.driveText = win:CreateFontString(nil, "OVERLAY")
            X.Text(win.driveText, win, 20, 17, 50, 31)
            S.Text(win.driveText, 0x25) -- the same native popup caption colour as the music CD field
            S.Picture(win, nil, "POPUPMNU.EPF", 0, "NPAL8.PAL", 16, 16)
            local centre = S.Picture(win, nil, "POPUPMNU.EPF", 1, "NPAL8.PAL", 18, 16)
            centre:SetWidth(34)
            S.Picture(win, nil, "POPUPMNU.EPF", 2, "NPAL8.PAL", 52, 16)
            win.drives.button:HookScript("OnClick", function()
                -- Restyle the existing dropdown's rows after it creates/reuses them.
                -- Its selection callback still owns Navigate; no new input dispatcher.
                if win.drives.list then
                    win.drives.list:SetBackdrop({ bgFile = "tk:white", bg = { S.Colour(S.WHITE) }, edge = { S.Colour(S.TEXT) } })
                    for _, row in ipairs(win.drives.list.items) do S.Text(row.label) end
                end
            end)
            X.TextButton(win, win.up, 72, 16, 108, 32)
            X.Text(win.path, win, 112, 17, 284, 31)
            win.path:SetSize(172, 12) win.path:SetWordWrap(false)
            win.viewport = X.Solid(win, "BACKGROUND", S.WHITE)
            X.Rect(win.viewport, win, 16, 32, 284, 282)
            X.Rect(win.list, win, 16, 32, 271, 282)
            win.list.content:SetWidth(255)
            win.list.wheelStep = 16
            win.folderBar = Bar.New(win, 271, 32, 282, 0, {
                Range = function()
                    local range = win.list:GetVerticalScrollRange()
                    local lines, offset = math.ceil(range / 16), win.list:GetVerticalScroll()
                    -- This pixel viewport can end partway through a 16px row. Its
                    -- clamped bottom is the final logical step, not the floored
                    -- preceding line. Keep other positions/Set in the bar's line
                    -- units; the other native adapters already supply whole lines.
                    return lines, offset >= range and lines or offset / 16, 15
                end,
                Set = function(pos) win.list:SetVerticalScroll(pos * 16) end,
            })
            -- The dialog manager sets its stack level after build/initial Navigate. Lift
            -- the existing bar when the window is shown so native art and its original
            -- ScrollPane left-press capture sit above this dialog's frame (4a 0x0055C400).
            -- Changing that ownership can change what the server sees; its 200/30ms
            -- repeat remains the shared bar's, with no new timer or dispatcher here.
            win:HookScript("OnShow", function()
                win.folderBar.frame:SetFrameLevel(win:GetFrameLevel() + 2)
                win.folderBar:Refresh()
            end)
            -- Reuse the native scrollbar seam and the shared viewport/wheel. The
            -- generic track stays hidden; there is only one visible bar.
            win.list.barStyle = function() win.list.track:Hide() win.folderBar:Refresh() end
            X.Image(win, win.choose, 14, 16, 286, 88, 302)
            X.Image(win, win.cancel, 22, 93, 286, 165, 302)
            -- Native has no default image button. The shared model still owns
            -- Enter/Escape semantics; native art never changes control IDs/focus.
        end,
        refresh = function(win, data)
            win.driveText:SetText(win.drives.text:GetText())
            for i, row in ipairs(win.rows) do
                if row.folderText then row.folderText:Hide() row.folderSelection:Hide() end
                if i <= #(data.folders or {}) then
                    X.Rect(row, win.list.content, 0, (i - 1) * 16, 255, i * 16)
                    -- As with the music controls, keep the shared input surface invisible.
                    -- Native text/selection are siblings in the shared clipped content, so
                    -- generic SetSelected/pressed tint cannot repaint a Modern button here.
                    X.Bare(row) -- retain the original controls' silent UI-click presentation
                    row:SetAlpha(0)
                    if not row.folderText then
                        row.folderText = win.list.content:CreateFontString(nil, "ARTWORK")
                        row.folderSelection = X.Solid(win.list.content, "BACKGROUND", 0x25)
                        row.folderSelection:SetAllPoints(row)
                        row:HookScript("OnUpdate", function(b) b.folderSelection:SetShown(b.selected == true) end)
                        row:HookScript("OnHide", function(b) b.folderText:Hide() b.folderSelection:Hide() end)
                    end
                    X.Text(row.folderText, row, 4, 1, 251, 15)
                    row.folderText:SetSize(247, 12) row.folderText:SetWordWrap(false) row.folderText:Show()
                    -- Refit the raw enumerated basename in the native font, never
                    -- the already-fitted shared caption. Values/Choose keep full paths.
                    local name = data.folders[i]:match("[^/\\]+$") or data.folders[i]
                    row.folderText:SetText(X.Fit(name, 247, S.TextWidth))
                    row:SetSelected(false)
                end
            end
            win.list.content:SetHeight(math.max(1, #(data.folders or {}) * 16))
        end,
    }
end
