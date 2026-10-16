-- s6-ui-core r66, X8: shared music controls. Looks own art/placement; the existing model owns original
-- indexes, matched releases and audio. Painting/settings refresh never commands or rescans the folder.
local C, W = TK.GetComponent("dialogs"), TK.UI
local K, H = C.kit, __tk
local Music = { look = "Music" }
local function at(f, win, x, y) f:SetPoint("TOPLEFT", win, "TOPLEFT", x, -y) end

-- Fit only the displayed path, measured in this label's font. Settings/Choose/native state keep the full path.
-- A retained unchanged label needs no refitting; its tooltip still exposes the complete folder.
local function pathText(label, text, width)
    if label.musicPath == text and label.musicPathWidth == width then return end
    label.musicPath, label.musicPathWidth = text, width
    label:SetWordWrap(false)
    label:SetText(TK.Util.FitText(text, width, function(value) label:SetText(value) return label:GetStringWidth() end))
end

-- Original RadioGroupControlPane selects on release inside an option (0x00496190), then commands only
-- on the matched release through K.Wire (MusicControlDialog 0x00529790). Changing that path changes
-- what the server sees; OneOf's programmatic SetValue stays silent.
local function radio(win, index, title, texts)
    local g = W.OneOf(win, title, 300)
    local choices = {}
    for i, text in ipairs(texts) do choices[i] = { value = i - 1, text = text } end
    g:Configure(title, choices)
    win.controls[index] = g
    for i, b in ipairs(g.buttons) do
        -- The tracked group's release may land over a different option, which selects without a command.
        -- An outside release selects nothing, so it cannot enable a folder scan absent from the original.
        b:HookScript("OnMouseUp", function(_, button)
            if button == "LeftButton" and g.enabled then
                for j, option in ipairs(g.buttons) do if option:IsMouseOver() then g:SetValue(j - 1) break end end
            end
        end)
        K.Wire(win, b, index, nil, 0x40 + i - 1)
    end
    return g
end

local function volume(win, index, title)
    local f = W.Slider(win, title, 0, 100, 1, 300, nil, { originalControl = true })
    f:SetValue(100) -- creates the shared handle before a native look places it
    win.controls[index] = f
    -- The slider's scripts set its value first, then the same physical event carries it to the model.
    -- 4a SliderControlPane::HandlePointerOrMouseEvent 0x004974B0; no polling-generated input or packets.
    for _, part in ipairs({ f.slider, f.thumbs[1] }) do
        -- 4a DialogPane 0x0049E240 matches the release's current hit part; Down retains the part before its step.
        -- A cached Up part can refresh Browse and allow shared C12 draws, changing what the server sees later.
        K.Wire(win, part, index, nil, function(down) return down and (f.activePart or 10) or f:OriginalPart() end)
        part:HookScript("OnPressedMove", function()
            if f.dragging then f:GetScript("OnUpdate")(f) end
            if f.activePart then K.Move(win, index) end
        end)
    end
    -- Native sliders have no editable number box. Keep one shared slider and remove this optional input surface.
    for _, box in ipairs(f.boxes) do box:Hide() end
    return f
end

function Music.build()
    local L = C.look.Music
    local win = K.Window(L.width, L.height, "Music")
    win.on, win.off = W.Button(win, "On", L.switch, L.buttonHeight), W.Button(win, "Off", L.switch, L.buttonHeight)
    K.Wire(win, win.on, 1, nil, 0x40) K.Wire(win, win.off, 1, nil, 0x41)
    win.controls[1], win.frequency, win.stored = win.on, 0, 0
    win.freq = {}
    for i, text in ipairs({ "Off", "22 kHz", "44 kHz" }) do
        local b = W.Button(win, text, L.frequency, L.buttonHeight)
        -- 4a radio 0x00496190 selects on release, including another option without a matched command.
        -- The model alone refreshes needs at 0x0049E240's matched release; changing it can add shared C12 draws.
        b:HookScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then
                for j, option in ipairs(win.freq) do if option:IsMouseOver() then win.frequency = j - 1 break end end
            end
        end)
        K.Wire(win, b, 3, nil, 0x40 + i - 1)
        win.freq[i] = b
    end
    win.controls[3] = win.freq[1]
    win.effectsVolume, win.musicVolume = volume(win, 2, "Effects volume"), volume(win, 4, "Music volume")
    win.source = radio(win, 5, "Music source", { "Zone music", "MP3 folder", "Audio CD" })
    win.folder = W.Button(win, "(none)", 174, 20)
    K.Wire(win, win.folder, 6) win.controls[6] = win.folder
    local drives = {}
    for _, drive in ipairs(H:DialogMusicCdDrives()) do drives[#drives + 1] = { value = drive, text = drive .. ":" } end
    drives[#drives + 1] = { value = "", text = "(none)" }
    win.cd = W.Dropdown(win, "CD drive", drives, 100)
    win.cd:SetValue("") K.Wire(win, win.cd.button, 8) win.controls[8] = win.cd
    -- PopupMenuControlPane 0x004984C0 opens on Up; MenuPane 0x00516940 owns close/consumption.
    -- Render the existing model request instead of the generic toggle/outside close. Changing ownership
    -- changes later accepted commands; this adds no input record or alternative click history.
    win.cd.modelMenu = true
    win.cd.button:SetScript("OnClick", function() end)
    -- MenuPane 0x00516940 restores the pointed row on a move, including within the same row after arrows.
    -- Read the host-kept cursor before Values and during Paint; a still cursor must not overwrite key selection.
    -- This changes no input record or packet, but changing the row changes the next callback/server-visible path.
    function win:CdHover()
        if not self.cd.list or not self.cd.list:IsShown() then return end
        local x, y = GetCursorPosition()
        if x == self.cd.menuX and y == self.cd.menuY then return end
        self.cd.menuX, self.cd.menuY = x, y
        for i, b in ipairs(self.cd.list.items) do
            if b:IsShown() and b:IsMouseOver() then self.cd.menuIndex = i - 1 break end
        end
    end
    -- The shared dropdown exposes its existing rows after opening. Their physical events keep control 8's
    -- posted input route. 4a MenuPane 0x00516940 chooses the RELEASE row before Close 0x00516670 refreshes;
    -- pressing inside chooses nothing. Changing that order/value changes later commands the server could see.
    function win:CdReleaseRow()
        self.cd.releaseHit = nil
        -- MenuPane 0x00516940 case3 chooses the enabled RELEASE row, regardless of the press's frame.
        -- Prepare this once before its physical descriptor; a second callback changes later accepted input.
        for j, row in ipairs(self.cd.list.items) do
            if row:IsShown() and row:IsEnabled() and row:IsMouseOver() then
                self.cd:SetValue(self.cd.values[j].value)
                self.cd.menuIndex, self.cd.releaseHit = j - 1, true
                break
            end
        end
    end
    function win:WireCdMenu()
        self.cd.menuX, self.cd.menuY = GetCursorPosition()
        self.cd.menuIndex = -1
        for i, choice in ipairs(self.cd.values) do
            if choice.value == self.cd:GetValue() then self.cd.menuIndex = i - 1 break end
        end
        if win.cd.list and not win.cd.list.musicWired then
            win.cd.list.musicWired = true
            -- MenuPane 0x00516940 takes its padding too; actual bounds stay frontend geometry, not map coordinates.
            -- Changing that consumption changes which later commands reach the server.
            K.Wire(win, win.cd.list, -1)
        end
        for _, b in ipairs(win.cd.list and win.cd.list.items or {}) do
            -- OpenList rebuilds generic click scripts on every show; retain original MenuPane ownership each time.
            b:SetScript("OnClick", function() end)
            if not b.musicWired then
                b.musicWired = true
                K.Wire(win, b, 8, function(button)
                    if button == "LeftButton" then win.cd.pending = true end
                end)
                -- Use one highlight for mouse and keys; the generic hover light must not keep another row lit.
                b.highlight:Hide()
                b.musicSelection = b:CreateTexture(nil, "ARTWORK")
                b.musicSelection:SetAllPoints(b)
                b.musicSelection:SetColorTexture(W.menuHighlight[1], W.menuHighlight[2], W.menuHighlight[3], W.menuHighlight[4])
            end
        end
    end
    W.Tip(win.cd.button, "Audio CDs are not played; this source is silent.")
    win.order = radio(win, 9, "Order", { "In order", "Random" })
    win.repeatMode = radio(win, 10, "Repeat", { "Repeat", "Once" })
    win.browse, win.prev, win.pause, win.next, win.ok = K.Button(win, 7, "Browse...", L.button),
        K.Button(win, 11, "|<", L.play), K.Button(win, 12, "||", L.play), K.Button(win, 13, ">|", L.play), K.Button(win, 14, "OK", L.button)
    -- The same declared needs can be consumed by every look; disabled original controls retain their values.
    win.effectsVolume.arg = { requires = { TK.Needs("Sound effects on", function(s) return s.effectsVolumeEnabled end, "disable") } }
    win.musicVolume.arg = { requires = { TK.Needs("Frequency on", function(s) return s.musicVolumeEnabled end, "disable") } }
    win.order.arg = { requires = { TK.Needs("Music source: MP3 folder or Audio CD", function(s) return s.activeSource ~= 0 end, "disable") } }
    win.repeatMode.arg = win.order.arg
    function win:Values()
        self:CdHover()
        local active = self.effectsVolume.activePart and self.effectsVolume or self.musicVolume
        local px, width, inside = active:OriginalPointer()
        -- Like other dialog lists, the host carries its actual open/highlight state with this input.
        -- 4a MenuPane 0x00516A70 takes those keys before Music's default/cancel; changing this route changes
        -- accepted commands and what the server sees. The catalog remains the already-built CD list.
        local choices = {}
        for _, choice in ipairs(self.cd.values) do choices[#choices + 1] = choice.value end
        return { self.frequency, self.stored, self.effectsVolume:GetValue(), self.musicVolume:GetValue(),
            self.source:GetValue(), self.order:GetValue(), self.repeatMode:GetValue(), self.cd:GetValue(),
            self.effectsVolume.activePart and self.effectsVolume:OriginalPart() or self.musicVolume.activePart and self.musicVolume:OriginalPart() or 10,
            math.floor(px * 1000), math.floor(width * 1000), inside and 1 or 0,
            self.cd.list and self.cd.list:IsShown() and 1 or 0, self.cd.menuIndex or -1, table.concat(choices, ','),
            -- MenuPane 0x00516940 takes the row's Down/double Down and chooses its Up without DialogPane
            -- tracking. Carry the already-kept row state in this same record; changing it changes later commands.
            self.cd.pending and 1 or 0, self.cd.releaseHit and 1 or 0,
            self.cd.list and self.cd.list:IsShown() and self.cd.list:IsMouseOver() and 1 or 0 }
    end
    function win:Paint()
        self:CdHover()
        local c = self.view and self.view.contents or {}
        -- MenuPane 0x00516940's release can close before the held frame's silent OnMouseUp preview.
        -- Reconcile that close from the model before hiding; keeping a rejected selection changes later input.
        local menuClosed = (self.cd.menuRevision or 0) ~= (c.cdMenuRevision or 0) and not c.cdMenuOpen and
            self.cd.list and self.cd.list:IsShown()
        -- MenuPane 0x00516940 consumes before the owner. Frontend scripts run before that model verdict;
        -- clear only their consumed or newly disabled slider drag/preview and render model selections. A lasting preview
        -- can change later accepted input; this sends nothing and starts no control capture or timer.
        if c.cdMenuOpen or not c.effectsVolumeEnabled then self.effectsVolume:Release(false) end
        if c.cdMenuOpen or not c.musicVolumeEnabled then self.musicVolume:Release(false) end
        if c.cdMenuOpen or menuClosed then
            self.frequency = c.frequency or 0
        end
        if not c.cdMenuOpen then
            self.cd.pending, self.cd.releaseHit = nil, nil
        end
        for i, b in ipairs(self.freq) do b:SetAlpha(i - 1 == self.frequency and 1 or 0.55) end
        local s = H:DialogMusicState() or { effects = self.view and self.view.contents.effects or 0,
            source = 0, folder = "", effectsVolume = 100, musicVolume = 100, order = 0, repeatMode = 1, cd = "" }
        local audio = TK.GetComponent("audio")
        if audio and H:DialogMusicState() then audio:RememberMusicDialog(s) end
        -- 4a radio 0x00496190 selects the RELEASE option without applying audio on a crossed release.
        -- Paint that model choice, but keep volume needs at 0x0049E240's matched-command/key refresh;
        -- changing those boundaries changes later accepted input and what the server sees.
        s.effects = c.effects or s.effects
        s.effectsVolumeEnabled = c.effectsVolumeEnabled == true
        s.activeSource = c.enabledSource or s.source -- follow the model's original refresh points, not Config alone
        s.musicVolumeEnabled = c.musicVolumeEnabled == true -- a display-only release does not refresh slider needs
        for _, item in ipairs({ { "source", "sourceSelection" }, { "order", "orderSelection" }, { "repeatMode", "repeatSelection" } }) do
            local key, field = table.unpack(item)
            if self.audioSeen and self.audioSeen[key] == s[key] then
                s[key] = (c.cdMenuOpen or menuClosed or self.musicView ~= self.view) and c[field] or self[key]:GetValue()
            end
        end
        self.audioSeen = H:DialogMusicState()
        self.musicView = self.view
        self.on:SetAlpha(s.effects == 1 and 0.55 or 1) self.off:SetAlpha(s.effects == 1 and 1 or 0.55)
        for _, key in ipairs({ "effectsVolume", "musicVolume", "source", "order", "repeatMode", "cd" }) do
            local f = self[key]
            if f.arg then f:SetEnabled(TK.NeedsMet(f.arg, s)) end
            if not f.dragging and not f.pending then f:SetValue(s[key]) end
            if f.boxes then for _, box in ipairs(f.boxes) do box:Hide() end end
        end
        pathText(self.folder:GetFontString(), s.folder ~= "" and s.folder or "(none)", self.folder:GetWidth() - 12)
        W.Tip(self.folder, s.folder ~= "" and s.folder or "No MP3 folder selected.")
        self.folder:SetEnabled(s.activeSource == 1) self.browse:SetEnabled(s.activeSource == 1)
        self.cd:SetEnabled(s.activeSource == 2)
        -- 4a PopulateCdDrivePopup 0x0052A010 leaves an unavailable saved letter unselected and blank.
        -- Keep Config/GetValue intact for control 8's original comparison; painting commands no playback
        -- and changes no packet order or shared random draw. The generic dropdown keeps its own behavior.
        local cdKnown = false
        for _, drive in ipairs(self.cd.values) do if drive.value == s.cd then cdKnown = true break end end
        if not cdKnown then self.cd.text:SetText("") end
        -- The model implements PopupMenuControlPane/MenuPane pointer and keys (0x004984C0 / 0x00516A70) in their
        -- own input record. Consume each request once: a later pointer/outside close must stay closed.
        -- This is presentation only; reopening from a stale snapshot could capture later server-visible input.
        if (self.cd.menuRevision or 0) ~= (c.cdMenuRevision or 0) then
            self.cd.menuRevision = c.cdMenuRevision
            if c.cdMenuOpen then
                if not self.cd.list or not self.cd.list:IsShown() then self.cd:OpenList() self:WireCdMenu() end
                self.cd.menuIndex = c.cdMenuIndex
            else self.cd:CloseList() end
        end
        for i, b in ipairs(self.cd.list and self.cd.list.items or {}) do
            if b.musicSelection then b.musicSelection:SetShown(i - 1 == self.cd.menuIndex) end
        end
        if L.paint then L.paint(self, s.effects) end
        if L.nativePaint and self.nativeControls then
            local state = {}
            for _, pair in ipairs({ { 2, self.effectsVolume }, { 4, self.musicVolume } }) do
                local id, f = table.unpack(pair)
                state[id] = { value = f:GetValue(), enabled = f.slider:IsEnabled(), focused = self.view and self.view.focus == id,
                    pressed = ({ [13] = "left", [14] = "before", [15] = "thumb", [16] = "after", [17] = "right" })[f.activePart] }
            end
            for _, pair in ipairs({ { 5, self.source }, { 9, self.order }, { 10, self.repeatMode } }) do
                local id, f = table.unpack(pair) state[id] = { value = f:GetValue(), enabled = f.enabled ~= false }
            end
            state[6] = { enabled = self.folder:IsEnabled(), text = s.folder }
            state[8] = { enabled = self.cd.button:IsEnabled(), text = self.cd:GetValue() ~= "" and self.cd.text:GetText() or "", focused = self.view and self.view.focus == 8 }
            L.nativePaint(self, self.nativeControls, state)
        end
    end
    -- Placement fallback is the existing settings look. Native lanes override only this new controls block.
    local base = TK.Dialogs.DefaultLook().Music
    base.placeControls(win)
    L.place(win)
    if L.placeControls and L ~= base then L.placeControls(win) end
    if L.nativePlace then
        -- Consume interface-5x's art-only contract; no native state/input/audio code is copied here.
        win.nativeControls = { [2] = win.effectsVolume.slider, [4] = win.musicVolume.slider, [5] = win.source.buttons,
            [6] = win.folder:GetFontString(), [8] = win.cd.button, [9] = win.order.buttons, [10] = win.repeatMode.buttons }
        L.nativePlace(win, win.nativeControls)
    end
    win:SetScript("OnUpdate", function(self) if self:IsShown() then self:Paint() end end)
    return win
end

function Music.update(win)
    if win.opened then
        win.frequency, win.stored, win.audioSeen = win.view.contents.frequency or 0, win.view.contents.stored or 0, nil
        win.cd:CloseList() win.cd.menuRevision, win.cd.menuIndex = 0, -1
    end
    win:Paint()
end
C.renderers.MusicControlDialog = Music

-- MenuPane 0x00516940 owns every left Up while open, including one held by padding or another frame.
-- Prepare its row once before that frame's OnMouseUp. Existing K.Pointer consumes the same physical serial;
-- the later K.Wire cannot post again. Altering that delivery/callback order changes what the server sees.
TK.On("GLOBAL_MOUSE_UP", function(_, button)
    if button ~= "LeftButton" then return end
    local win = C:Find("MusicControlDialog")
    -- EventDispatcher 0x004A7130 offers the front modal first; Music behind a newer dialog cannot take its Up.
    if not win or not win.view or not win.view.front or not win.cd.list or not win.cd.list:IsShown() then return end
    win:CdReleaseRow()
    K.Pointer(win, win.cd.releaseHit and 8 or -1, button, false)
    -- Down already marked consumed presses (0x00516940). Do not set Taken on Up after the host has read it;
    -- preserve outside-single-Down pass-through and its accepted slider capture from the original close/refresh.
    win.cd.pending, win.cd.releaseHit = nil, nil
end)

-- Reuse the popup bridge's deferred no-action fallback: an underlying control keeps its same record.
-- Live already has that physical record; offline a blank outside Down otherwise posts none. MenuPane
-- 0x00516940 decides its actual single/double/right kind in Core; probing Press here changes click history.
TK.On("GLOBAL_MOUSE_DOWN", function(_, button)
    local win = C:Find("MusicControlDialog")
    if not win or not win.cd or not win.cd.list or not win.cd.list:IsShown() then return end
    -- Close 0x00516670 refreshes before the same outside type1 reaches a slider. Prepare the existing
    -- handler even when the retained needs had it disabled; Core Refresh alone accepts/rejects its result.
    -- This keeps originalPress's part/step/drag arithmetic, with no copied needs or extra command/record.
    win.effectsVolume:SetEnabled(true) win.musicVolume:SetEnabled(true)
    local x, y = GetCursorPosition()
    H:DialogDismissOnPress(button or "LeftButton", math.floor(x), math.floor(y))
end)

-- D-64 is the existing Browse route, not another Sound window. Folder enumeration is presentation only;
-- Choose(1) sends the path to the model once. 4a FolderSelectDialog::OnControlCommand 0x004B1920 and
-- FolderPathSelected 0x00529EE0: Cancel(2)/empty paths never scan, so the wire's random stream stays unchanged.
local Folder = { look = "FolderSelect" }
function Folder.build()
    local L = C.look.FolderSelect
    local win = K.Window(L.width, L.height, "MP3 folder")
    win.path = W.Label(win, "", 12, W.white, "LEFT")
    win.path:SetWordWrap(true)
    -- Only hovering the path reveals its complete text; blank picker space must not show a path tooltip.
    win.pathTip = CreateFrame("Frame", nil, win)
    win.pathTip:SetAllPoints(win.path)
    win.drives = W.Dropdown(win, "Drive", {}, 260, function(path) win:Navigate(path) end)
    win.up = W.Button(win, "Up", 55, 22)
    win.up:SetScript("OnClick", function() win:Navigate(win.parentPath) end)
    win.list = W.ScrollArea(win)
    win.rows = {}
    win.choose, win.cancel = K.Button(win, 1, "Choose", 90), K.Button(win, 2, "Cancel", 90)
    win.buttons = { win.cancel, win.choose } -- existing generic-look test/placement order
    function win:Values() return { self.selected or "" } end
    function win:Navigate(path)
        local data = H:DialogMusicFolders(path or "")
        self.problem, self.parentPath = data.problem, data.parent
        self.selected = data.path or ""
        pathText(self.path, data.problem or self.selected, self.path:GetWidth())
        W.Tip(self.pathTip, data.problem or self.selected)
        self.choose:SetEnabled(not data.problem)
        local drives = {}
        for _, drive in ipairs(data.drives) do drives[#drives + 1] = { value = drive, text = drive } end
        self.drives:SetValues(drives)
        self.drives:SetValue(self.selected:sub(1, 3))
        for _, b in ipairs(self.rows) do b:Hide() end
        for i, path2 in ipairs(data.folders or {}) do
            local b = self.rows[i] or W.Button(self.list.content, "", 260, 22)
            self.rows[i] = b
            b:ClearAllPoints() b:SetPoint("TOPLEFT", self.list.content, "TOPLEFT", 0, -(i - 1) * 24)
            pathText(b:GetFontString(), path2:match("[^/\\]+$") or path2, b:GetWidth() - 12)
            W.Tip(b, path2)
            -- FolderTreePane: a click selects, a double press opens. Only Choose scans MP3s; local navigation
            -- never calls audio or moves the random stream shared by the wire.
            b:SetScript("OnClick", function()
                -- 4a FolderTreePane::OnMouseEvent 0x004B2DC0 expands the selected node on a double
                -- press without reselecting a new child on release. Navigate reuses this frame;
                -- consume that release before its replacement child handler can change Choose's
                -- path/C12 draws. Changing this boundary changes what the server sees.
                if b.folderDoublePress then b.folderDoublePress = nil return end
                win.selected = path2 pathText(win.path, path2, win.path:GetWidth()) W.Tip(win.pathTip, path2)
                for _, row in ipairs(win.rows) do row:SetSelected(row == b) end
            end)
            b:SetScript("OnMouseDown", function(_, button, double)
                if button == "LeftButton" then
                    -- A later single Down clears a double whose outside release never clicked.
                    -- This preserves ordinary selection and 0x004B2DC0's selected-node semantics.
                    b.folderDoublePress = double == true
                    if double then win:Navigate(path2) end
                end
            end)
            b:Show()
        end
        self.list.content:SetHeight(math.max(1, #(data.folders or {}) * 24))
        -- Native looks reapply row/font/viewport presentation after each completed enumeration.
        -- This callback must not navigate, command, scan or draw random numbers: 4a FolderTreePane
        -- and FolderPathSelected 0x00529EE0 leave those to the shared routes above; changing them
        -- changes what the server sees through the wire-shared C12 stream.
        if L.refresh then L.refresh(self, data) end
        self.list:ScrollToTop()
    end
    L.place(win)
    return win
end
function Folder.update(win)
    if win.opened then
        local s = H:DialogMusicState()
        win:Navigate(s and s.folder or "")
    end
end
C.renderers.FolderSelectDialog = Folder
