-- The Library page's Export and Import dialogs (s6-library round 2, head note 5; moved out of library.lua by
-- s6-library-pages): a server's Library to a file, and a file into it (Replace or Merge, a backup first if wanted). The
-- file work runs on the Library's queue as jobs the dialogs wait for (library.lua's Await); nothing is sent to a server.

local W = TK.UI
local H = __tk
local L = TK.Library

local X = {}
TK.LibraryExchange = X

local function dialog(name, title, height)
    local d = W.PopupPanel(W.Panel(UIParent, name)) -- s6-ui-core (round 56): solid over the Library's window, a popup
    d:SetFrameStrata("FULLSCREEN_DIALOG")
    d:SetFrameLevel(90)
    d:SetSize(520, height)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    d:EnableMouse(true)
    d.title = W.Label(d, title, 15, W.gold)
    d.title:SetPoint("TOP", d, "TOP", 0, -14)
    d.text = W.Label(d, "", 12, W.white, "LEFT")
    d.text:SetWordWrap(true)
    d.text:SetWidth(480)
    d.text:SetPoint("TOPLEFT", d, "TOPLEFT", 20, -40)
    d.message = W.Label(d, "", 12, { 1, 0.6, 0.35 }, "LEFT")
    d.message:SetWordWrap(true)
    d.message:SetWidth(480)
    d:Hide()
    -- Round 4 (review r3 finding 2): each opening is a session of its own; what an earlier one started never acts on it.
    d:HookScript("OnHide", function() d.session = nil end)
    TK.Escape:AddWindow(d, function() d:Hide() end)
    return d
end

X.Dialog = dialog -- s6-library round 16: the prebuilt Library's dialog is one of these (library/prebuild.lua)

--- A file job's answer for the dialog, if it is still the opening that asked (not closed, nor opened again since).
local function awaitIn(d, job, done)
    local session = d.session
    L.Await(job, function(answer)
        if session ~= nil and d.session == session then done(answer) end
    end)
end

--- A location row: a label, an edit box with the path, and a Browse button (the system's dialog, behind the seam).
local function locationRow(d, y, label, browse)
    local l = W.Label(d, label, 12, W.gold, "LEFT")
    l:SetPoint("TOPLEFT", d, "TOPLEFT", 20, y)
    local box = W.EditBox(d, 380, 22)
    box:SetPoint("TOPLEFT", d, "TOPLEFT", 20, y - 18)
    local b = W.Button(d, "Browse...", 90, 24, nil, function()
        awaitIn(d, browse(), function(path) if path ~= "" then box:SetText(path) end end)
    end)
    b:SetPoint("LEFT", box, "RIGHT", 10, 0)
    return box, b, l
end

--- The Export dialog for a server: "Export private character information" (off), a location with Browse, Export.
function X:OpenExport(server)
    local d = self.export
    if not d then
        d = dialog("TKLibraryExport", "Export the Library", 230)
        d.private = W.Check(d, "Export private character information")
        d.private:SetPoint("TOPLEFT", d, "TOPLEFT", 20, -64)
        d.privateNote = W.Label(d, "Your characters (bank, inventory, equipment, gold, stats, spells) and the players you met.", 11, { 0.7, 0.7, 0.75 }, "LEFT")
        d.privateNote:SetPoint("TOPLEFT", d.private, "BOTTOMLEFT", 24, -2)
        d.path, d.browse = locationRow(d, -108, "Location", function()
            return H:LibraryBrowseSave(H:LibraryExportName(d.server, false))
        end)
        d.go = W.Button(d, "Export", 100, 26, "red", function() X:Export() end)
        d.go:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -6, 14)
        d.cancel = W.Button(d, "Close", 100, 26, nil, function() d:Hide() end)
        d.cancel:SetPoint("BOTTOMLEFT", d, "BOTTOM", 6, 14)
        d.message:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 20, 48)
        self.export = d
    end
    d.server = server
    d.text:SetText("Server: " .. server)
    d.private:SetChecked(false)
    d.path:SetText("")
    d.message:SetText("")
    d.session = {}
    d:Show()
end

function X:Export()
    local d = self.export
    local path = d.path:GetText()
    d.message:SetText("Exporting...")
    awaitIn(d, H:LibraryExport(d.server, path, d.private:GetChecked() and true or false), function(result)
        d.message:SetText(result == "" and ("Exported to " .. path) or ("Not exported: " .. result))
    end)
end

--- The Import dialog for a server: a location with Browse; then Replace or Merge; then a backup, if wanted, first.
--- s6-library round 18 (the owner: the prebuilt Library under Import; FOR s6-library-pages): when the build ships a
--- prebuilt Library, a first step chooses "Prebuilt Library" (its dialog, library/prebuild.lua) or "File on disk" (the
--- import above, unchanged).
function X:OpenImport(server)
    local d = self.import
    if not d then
        d = dialog("TKLibraryImport", "Import into the Library", 270)
        d.path, d.browse, d.pathLabel = locationRow(d, -64, "File to import", function() return H:LibraryBrowseOpen() end)
        d.next = W.Button(d, "Next", 100, 26, "red", function() X:ImportNext() end)
        d.next:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -6, 14)
        d.replace = W.Button(d, "Replace", 100, 26, "red", function() X:ChooseMode("replace") end)
        d.replace:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -60, 14)
        d.merge = W.Button(d, "Merge", 100, 26, "red", function() X:ChooseMode("merge") end)
        d.merge:SetPoint("BOTTOMLEFT", d, "BOTTOM", -54, 14)
        d.yes = W.Button(d, "Yes", 100, 26, "red", function() X:Backup(true) end)
        d.yes:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -60, 14)
        d.no = W.Button(d, "No", 100, 26, nil, function() X:Backup(false) end)
        d.no:SetPoint("BOTTOMLEFT", d, "BOTTOM", -54, 14)
        d.backupPath, d.backupBrowse, d.backupLabel = locationRow(d, -150, "Backup location", function()
            return H:LibraryBrowseSave(H:LibraryExportName(d.server, true))
        end)
        d.go = W.Button(d, "Back up and import", 150, 26, "red", function() X:BackupAndImport() end)
        d.go:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -6, 14)
        d.cancel = W.Button(d, "Close", 100, 26, nil, function() d:Hide() end)
        d.cancel:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -14, 14)
        d.message:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 20, 48)
        d.prebuilt = W.Button(d, "Prebuilt Library", 150, 26, "red", function() -- s6-library round 18
            d:Hide()
            TK.LibraryPrebuild:OpenDialog(d.server)
        end)
        d.prebuilt:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -60, 14)
        d.fromFile = W.Button(d, "File on disk", 150, 26, "red", function() X:Step("file") end)
        d.fromFile:SetPoint("BOTTOMLEFT", d, "BOTTOM", -54, 14)
        self.import = d
    end
    d.server, d.mode, d.info = server, nil, nil
    d.path:SetText("")
    d.backupPath:SetText("")
    self:Step(H:LibraryPrebuildVersions() ~= "" and "source" or "file") -- s6-library round 18
    d.session = {}
    d:Show()
end

--- Shows one step of the import: ("source", round 18), "file", "mode", "backup?", "backup", "done".
function X:Step(step)
    local d = self.import
    d.step = step
    d.prebuilt:SetShown(step == "source")
    d.fromFile:SetShown(step == "source")
    d.path:SetShown(step == "file")
    d.browse:SetShown(step == "file")
    d.next:SetShown(step == "file")
    d.replace:SetShown(step == "mode")
    d.merge:SetShown(step == "mode")
    d.yes:SetShown(step == "backup?")
    d.no:SetShown(step == "backup?")
    d.backupPath:SetShown(step == "backup")
    d.backupBrowse:SetShown(step == "backup")
    d.go:SetShown(step == "backup")
    d.pathLabel:SetShown(step == "file")
    d.backupLabel:SetShown(step == "backup")
    if step == "file" or step == "source" then
        d.text:SetText("Into: " .. d.server)
        d.message:SetText("")
    end
end

function X:ImportNext()
    local d = self.import
    d.message:SetText("Reading the file...")
    awaitIn(d, H:LibraryImportInfo(d.path:GetText()), function(info)
        if not info.ok then
            d.message:SetText("Not imported: " .. info.problem)
            return
        end
        d.info = info
        local text = "This file holds " .. info.parts .. " from " .. info.server .. " (" .. info.date .. ")"
            .. (info.private and ", with private character information." or ".")
        if info.server ~= d.server then
            text = text .. "\nIt comes from another server's address (" .. info.server .. "): importing it into " .. d.server .. " is allowed."
        end
        d.text:SetText(text .. "\n\nReplace: each part the file holds replaces this server's. Merge: new entries are added; where both have one, the one seen most recently is kept.")
        d.message:SetText("")
        self:Step("mode")
    end)
end

function X:ChooseMode(mode)
    local d = self.import
    d.mode = mode
    d.text:SetText((mode == "replace" and "Replace" or "Merge") .. " " .. d.server .. "'s Library with this file.\n\nCreate a backup of the current data?")
    self:Step("backup?")
end

function X:Backup(yes)
    local d = self.import
    if yes then
        d.text:SetText("Where should the backup go? It holds everything, private character information included.")
        self:Step("backup")
    else
        self:Import()
    end
end

--- The import the player approved: its server, file and mode as the dialog showed them at that moment.
local function approved(d) return { server = d.server, path = d.path:GetText(), mode = d.mode } end

function X:BackupAndImport()
    local d = self.import
    -- Round 4 (review r3 finding 2): the approved import is taken before the backup starts. If the dialog is closed or
    -- opened again while the backup is written, its answer imports nothing (the backup stays written).
    local op = approved(d)
    op.backup = d.backupPath:GetText()
    d.message:SetText("Writing the backup...")
    awaitIn(d, H:LibraryExport(op.server, op.backup, true), function(result)
        if result ~= "" then
            d.message:SetText("The backup could not be written (" .. result .. "): nothing was imported.")
            return
        end
        self:Import(op)
    end)
end

function X:Import(op)
    local d = self.import
    op = op or approved(d)
    if op.mode ~= "replace" and op.mode ~= "merge" then return end
    d.message:SetText("Importing...")
    local session = d.session
    L.Await(H:LibraryImport(op.server, op.path, op.mode), function(result)
        if L:IsOpen() then L:Refresh() end
        if session == nil or d.session ~= session then return end
        if result == "" then
            d.text:SetText("Imported (" .. op.mode .. ") into " .. op.server .. "." .. (op.backup and ("\nBackup: " .. op.backup) or ""))
            d.message:SetText("")
        else
            d.message:SetText("Not imported: " .. result)
        end
        self:Step("done")
    end)
end
