-- Native folder presentation over the shared X8 enumeration/navigation renderer.
-- 5.33 constructor 0x0042EF20: 300x316, drive (16,16)-(66,32), viewport
-- (16,32)-(284,282), image 14/22 buttons. The existing geometry topic note
-- records these rectangles. Up/path expose the shared flat-list navigation;
-- this look does not add an expandable tree or replace shared 7.5.2 commands.
--
-- s6-ui-core (round 85): the XML twin's; the window's size and the parts' places, pictures and colours are folder.xml's
-- (core/xml.md).
local S = require("interfaces.5x.skin")
local Bar = require("interfaces.5x.scrollbar")
local unpack = table.unpack
local entry = require("interfaces.xml.entry")
local F = TK.Xml.Data("folder.xml").FolderSelect

return function(L, X)
    local ROWS, POPUP = F.rows, F.popup
    L.FolderSelect = entry(F, {
        place = function(win)
            local frame = X.DIALOG_FRAME
            X.Frame(win, F.width, F.height, frame.file, frame.palette, frame.tile)
            -- The native window owns its art; shared Choose/Cancel IDs and matched
            -- releases remain FolderSelectDialog 0x004B1920's. Changing those
            -- routes changes what the server sees through C12 0x0057A890.
            X.Rect(win.drives, win, unpack(F.drives))
            win.drives.title:Hide()
            X.Rect(win.drives.button, win, unpack(F.drives))
            win.drives.button:SetBackdrop(nil)
            win.drives.button:SetAlpha(0) -- shared popup input; native field painted below
            X.Text(win.drives.text, win, unpack(F.driveText))
            win.driveText = win:CreateFontString(nil, "OVERLAY")
            X.Text(win.driveText, win, unpack(F.driveText))
            S.Text(win.driveText, POPUP.text) -- the same native popup caption colour as the music CD field
            S.Picture(win, nil, POPUP.file, 0, POPUP.palette, POPUP.left, POPUP.top)
            local centre = S.Picture(win, nil, POPUP.file, 1, POPUP.palette, POPUP.middle, POPUP.top)
            centre:SetWidth(POPUP.width)
            S.Picture(win, nil, POPUP.file, 2, POPUP.palette, POPUP.right, POPUP.top)
            win.drives.button:HookScript("OnClick", function()
                -- Restyle the existing dropdown's rows after it creates/reuses them.
                -- Its selection callback still owns Navigate; no new input dispatcher.
                if win.drives.list then
                    win.drives.list:SetBackdrop({ bgFile = "tk:white", bg = { S.Colour(S.WHITE) }, edge = { S.Colour(S.TEXT) } })
                    for _, row in ipairs(win.drives.list.items) do S.Text(row.label) end
                end
            end)
            X.TextButton(win, win.up, unpack(F.up))
            X.Text(win.path, win, unpack(F.path))
            win.path:SetSize(unpack(F.pathSize)) win.path:SetWordWrap(false)
            win.viewport = X.Solid(win, "BACKGROUND", S.WHITE)
            X.Rect(win.viewport, win, unpack(F.viewport))
            X.Rect(win.list, win, unpack(F.list))
            win.list.content:SetWidth(ROWS.width)
            win.list.wheelStep = ROWS.height
            local B = F.bar
            win.folderBar = Bar.New(win, B.x, B.t, B.b, B.skin, {
                Range = function()
                    local range = win.list:GetVerticalScrollRange()
                    local lines, offset = math.ceil(range / ROWS.height), win.list:GetVerticalScroll()
                    -- This pixel viewport can end partway through a 16px row. Its
                    -- clamped bottom is the final logical step, not the floored
                    -- preceding line. Keep other positions/Set in the bar's line
                    -- units; the other native adapters already supply whole lines.
                    return lines, offset >= range and lines or offset / ROWS.height, ROWS.page
                end,
                Set = function(pos) win.list:SetVerticalScroll(pos * ROWS.height) end,
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
            X.Image(win, win.choose, unpack(F.choose))
            X.Image(win, win.cancel, unpack(F.cancel))
            -- Native has no default image button. The shared model still owns
            -- Enter/Escape semantics; native art never changes control IDs/focus.
        end,
        refresh = function(win, data)
            win.driveText:SetText(win.drives.text:GetText())
            local h = ROWS.height
            for i, row in ipairs(win.rows) do
                if row.folderText then row.folderText:Hide() row.folderSelection:Hide() end
                if i <= #(data.folders or {}) then
                    X.Rect(row, win.list.content, 0, (i - 1) * h, ROWS.width, i * h)
                    -- As with the music controls, keep the shared input surface invisible.
                    -- Native text/selection are siblings in the shared clipped content, so
                    -- generic SetSelected/pressed tint cannot repaint a Modern button here.
                    X.Bare(row) -- retain the original controls' silent UI-click presentation
                    row:SetAlpha(0)
                    if not row.folderText then
                        row.folderText = win.list.content:CreateFontString(nil, "ARTWORK")
                        row.folderSelection = X.Solid(win.list.content, "BACKGROUND", ROWS.selected)
                        row.folderSelection:SetAllPoints(row)
                        row:HookScript("OnUpdate", function(b) b.folderSelection:SetShown(b.selected == true) end)
                        row:HookScript("OnHide", function(b) b.folderText:Hide() b.folderSelection:Hide() end)
                    end
                    X.Text(row.folderText, row, unpack(F.rowText))
                    row.folderText:SetSize(unpack(F.rowTextSize)) row.folderText:SetWordWrap(false) row.folderText:Show()
                    -- Refit the raw enumerated basename in the native font, never
                    -- the already-fitted shared caption. Values/Choose keep full paths.
                    local name = data.folders[i]:match("[^/\\]+$") or data.folders[i]
                    row.folderText:SetText(X.Fit(name, F.rowTextSize[1], S.TextWidth))
                    row:SetSelected(false)
                end
            end
            win.list.content:SetHeight(math.max(1, #(data.folders or {}) * h))
        end,
    })
end
