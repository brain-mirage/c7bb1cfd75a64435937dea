-- The WoW-style frame API over the C# UI host.
--
-- C# knows UI objects only by integer handles. Here each handle is wrapped in a Lua table whose metatable gives
-- it WoW's methods (SetPoint, SetScript, CreateTexture, ...). Components can keep their own fields on these
-- tables, as WoW addons do. Scripts and event registrations live on the Lua side; C# is only told which scripts
-- exist so it knows what to call back.

local H = __tk
local objects = {}          -- handle -> object
TK.objects = objects

local function safe(fn, ...)
    return TK.SafeCall(fn, ...)
end

-- ----- classes -----

local Region = {}
Region.__index = Region

local Texture = setmetatable({}, { __index = Region })
Texture.__index = Texture

local FontString = setmetatable({}, { __index = Region })
FontString.__index = FontString

local Frame = setmetatable({}, { __index = Region })
Frame.__index = Frame

local function subclass(base)
    local c = setmetatable({}, { __index = base })
    c.__index = c
    return c
end

local Button = subclass(Frame)
local CheckButton = subclass(Button)
local StatusBar = subclass(Frame)
local Slider = subclass(Frame)
local EditBox = subclass(Frame)
local ScrollFrame = subclass(Frame)
local Cooldown = subclass(Frame)
local WorldView = subclass(Frame)

local classes = {
    Frame = Frame, Button = Button, CheckButton = CheckButton, StatusBar = StatusBar, Slider = Slider,
    EditBox = EditBox, ScrollFrame = ScrollFrame, Cooldown = Cooldown, WorldView = WorldView,
    Texture = Texture, FontString = FontString,
}
TK.FrameClasses = classes

local function wrap(h)
    if h == nil or h == 0 then return nil end
    local o = objects[h]
    if o then return o end
    local class = classes[H:GetObjectType(h)] or Frame
    o = setmetatable({ __h = h }, class)
    objects[h] = o
    return o
end
TK.Wrap = wrap

local function handleOf(x)
    if x == nil then return 0 end
    if type(x) == "table" then return x.__h or 0 end
    if type(x) == "string" then
        local f = _G[x]
        if type(f) ~= "table" or not f.__h then
            -- An unknown name is a mistake, not a request for the parent (review, optional improvements).
            error("no frame named '" .. x .. "'", 3)
        end
        return f.__h
    end
    return 0
end

-- ----- templates -----

TK.templates = {}

--- Registers a template: a function(frame) run by CreateFrame when the template is named.
function TK.RegisterTemplate(name, fn)
    TK.templates[name] = fn
end

local function applyTemplates(obj, templates)
    if not templates then return end
    for name in tostring(templates):gmatch("[^,%s]+") do
        local fn = TK.templates[name]
        if fn then safe(fn, obj) else H:LogError("unknown template " .. name) end
    end
end

-- ----- global functions -----

function CreateFrame(frameType, name, parent, template)
    local ph = handleOf(parent)
    local h = H:CreateFrame(frameType or "Frame", name or "", ph)
    local f = wrap(h)
    f.__name = name
    if name and name ~= "" then _G[name] = f end
    -- s6-interface-5x (round 13, the separation's step 11): an interface panel making it owns it, so the frame goes when
    -- the panel is turned off (TK.Components:FrameOwner, Unload)
    local C = TK.Components
    if C and C.FrameOwner then C:Adopt(f, C:FrameOwner(ph == 0 or (UIParent ~= nil and ph == UIParent.__h))) end
    applyTemplates(f, template)
    return f
end

function GetTime() return H:GetTime() end
function GetCursorPosition() return H:GetCursorPosition() end
function GetScreenWidth() return H:GetScreenWidth() end
function GetScreenHeight() return H:GetScreenHeight() end
function GetFramerate() return H:GetFramerate() end
function IsShiftKeyDown() return H:IsShiftKeyDown() end
function IsControlKeyDown() return H:IsControlKeyDown() end
function IsAltKeyDown() return H:IsAltKeyDown() end
function IsModifierKeyDown() return H:IsShiftKeyDown() or H:IsControlKeyDown() or H:IsAltKeyDown() end
function GetMouseFocus() return wrap(H:GetMouseFocus()) end
--- s6-input (round 51, Astra's self-review 51-1): the frame a press of button (default the left) would reach under the
--- pointer now: a frame claiming that button's presses over the mouse focus (SetClaimButtons: 7.x's minimap button, its
--- scroll bars), else the focus; nil for none. Where a press begins (wire: LuaApi.GetPressTarget).
function TK.PressTarget(button) return wrap(H:GetPressTarget(button or "LeftButton")) end
--- s6-input (round 51, Astra's self-review 51-2): the frame a release of button (default the left) reaches under the
--- pointer now: TK.PressTarget's, but a claiming frame that did not take this press lets it through to the focus unless
--- it takes every release over it (Frame:SetTakesEveryRelease). A release's control is hit-tested against it (wire:
--- LuaApi.GetReleaseTarget).
function TK.ReleaseTarget(button) return wrap(H:GetReleaseTarget(button or "LeftButton")) end
function ReloadUI() H:ReloadUI() end

function TK.UIScale() return H:GetUIScale() end
function TK.SetUIScale(s) H:SetUIScale(s) end

-- ----- script and event dispatch -----

function TK.DispatchScript(h, script, a1, a2)
    local o = objects[h]
    if not o then return end
    local scripts = o.__scripts
    local fn = scripts and scripts[script]
    if fn then safe(fn, o, a1, a2) end
end

local eventFrames = {}      -- event -> { frame = true }
local listeners = {}        -- event -> { { fn, __owner, __panel }, ... } for framework code (TK.Mark)

--- Framework-level event listener (not tied to a frame). s6-interface-5x (round 13, the separation's step 11): an
--- interface panel's own (TK.Components:Owner, marked as a registry's entry: TK.Mark) is withdrawn when the panel is
--- turned off (TK.WithdrawListeners).
function TK.On(event, fn)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], TK.Mark({ fn = fn }))
end

function TK.DispatchEvent(event, ...)
    local list = listeners[event]
    if list then
        -- a listener withdrawn meanwhile (a panel turned off by an earlier one) is skipped
        for _, l in ipairs(list) do
            if not l.gone then safe(l.fn, event, ...) end
        end
    end
    local set = eventFrames[event]
    if not set then return end
    -- Copy first: handlers may register or unregister.
    local frames = {}
    for f in pairs(set) do frames[#frames + 1] = f end
    for _, f in ipairs(frames) do
        local fn = f.__scripts and f.__scripts.OnEvent
        if fn then safe(fn, f, event, ...) end
    end
end

--- Fires an event to Lua listeners and frames, as if C# had sent it.
function TK.FireEvent(event, ...) TK.DispatchEvent(event, ...) end

-- ----- what an interface panel made (s6-interface-5x, round 13, the separation's step 11; interface-separation.md 5.18):
-- its listeners and frames, by their owner (a component's name) and the panel PanelOn made them for -----

--- Delivers an event to one owner's listeners and event frames alone (panel: only those made for that panel): a panel
--- started in the game gets what the client's start gave the others (TK.Components:Start). Wire: its PLAYER_LOGIN is
--- where that panel's pages attach their requests (TK.Game.Views.RequestPage: the self look's 2D 00, 4a's UserPane
--- RequestLocalPlayerStatus, UserPane.cpp:1546; the group's 2D 01, NewGroupPane::OnActivate 0x0056CB80), so its first
--- press sends what it sends after a start with it on; delivering to other owners, or to fewer, changes what the
--- server sees.
function TK.DeliverTo(owner, panel, event, ...)
    for _, l in ipairs(listeners[event] or {}) do
        if not l.gone and TK.OwnedBy(l, owner, panel) then safe(l.fn, event, ...) end
    end
    local frames = {}
    for f in pairs(eventFrames[event] or {}) do
        if TK.OwnedBy(f, owner, panel) then frames[#frames + 1] = f end
    end
    for _, f in ipairs(frames) do
        local fn = f.__scripts and f.__scripts.OnEvent
        if fn then safe(fn, f, event, ...) end
    end
end

--- Whether an owner (panel: what was made for that panel) has a listener or an event frame for an event.
function TK.Listens(owner, panel, event)
    for _, l in ipairs(listeners[event] or {}) do
        if not l.gone and TK.OwnedBy(l, owner, panel) then return true end
    end
    for f in pairs(eventFrames[event] or {}) do
        if TK.OwnedBy(f, owner, panel) then return true end
    end
    return false
end

--- Withdraws an owner's listeners (panel: only those made for that panel).
function TK.WithdrawListeners(owner, panel)
    for event, list in pairs(listeners) do
        local kept = {}
        for _, l in ipairs(list) do
            if TK.OwnedBy(l, owner, panel) then l.gone = true else kept[#kept + 1] = l end
        end
        listeners[event] = kept
    end
end

-- A destroyed object's table: every method does nothing, as code dropped with its panel may still hold it; its own
-- fields (__h, __scripts...) read nil.
local function nop() end
local Dead = {}
Dead.__index = Dead
setmetatable(Dead, { __index = function(_, k)
    if type(k) == "string" and k:sub(1, 2) == "__" then return nil end
    return nop
end })

--- Destroys a frame with everything below it (the host's UIHost.DestroyTree): their tables are dropped from the frame
--- API, their global names and their events, and become dead (TK.IsDead). Drawing only: nothing is sent.
function TK.DestroyFrame(f)
    if type(f) ~= "table" or not f.__h then return end
    for _, h in ipairs(H:DestroyFrame(f.__h)) do
        local o = objects[h]
        if o then
            objects[h] = nil
            if o.__name and o.__name ~= "" and _G[o.__name] == o then _G[o.__name] = nil end
            for _, set in pairs(eventFrames) do set[o] = nil end
            o.__scripts, o.__h, o.__dead = nil, nil, true
            setmetatable(o, Dead)
        end
    end
end

--- Whether an object was destroyed (TK.DestroyFrame): the registries drop what they hold of it.
function TK.IsDead(o) return type(o) == "table" and rawget(o, "__dead") == true end

-- The registries' part (here, as some load before core/components.lua): each marks what it is given with its owner
-- (TK.Mark) and drops it when that owner's panel is turned off (TK.OnWithdraw).
local withdrawers = {}

--- A registry's withdrawal: fn(name, panel) drops what that owner gave it (panel: only what was made for that panel),
--- and what it holds of destroyed frames (TK.IsDead); name nil: only the latter.
function TK.OnWithdraw(fn) withdrawers[#withdrawers + 1] = fn end

--- Runs every registry's withdrawal (TK.Components' tear-down).
function TK.Withdraw(name, panel)
    for _, fn in ipairs(withdrawers) do safe(fn, name, panel) end
end

--- Marks a registry's entry with the owner of what is made now (TK.Components:Owner, of the registry function's
--- caller). Returns it.
function TK.Mark(entry)
    local C = TK.Components
    if C and C.Owner then entry.__owner, entry.__panel = C:Owner(3) end
    return entry
end

--- Whether an entry (TK.Mark) or frame (TK.Components:Adopt) is that owner's (panel: made for that panel).
function TK.OwnedBy(entry, name, panel)
    return name ~= nil and rawget(entry, "__owner") == name and (panel == nil or rawget(entry, "__panel") == panel)
end

--- Drops from an array, in place, the entries that owner gave (TK.OwnedBy) and, with frameKey, those whose frame is
--- destroyed.
function TK.DropOwned(list, name, panel, frameKey)
    local j = 0
    for i = 1, #list do
        local e = list[i]
        if not TK.OwnedBy(e, name, panel) and not (frameKey and TK.IsDead(e[frameKey])) then
            j = j + 1
            list[j] = e
        end
    end
    for i = #list, j + 1, -1 do list[i] = nil end
end

-- ----- Region: shared by textures, font strings and frames -----

function Region:GetObjectType() return H:GetObjectType(self.__h) end
function Region:IsObjectType(t) return self:GetObjectType() == t end
function Region:GetName() return self.__name end
function Region:GetParent() return wrap(H:GetParent(self.__h)) end

--- SetPoint(point [, relativeTo [, relativePoint]] [, x, y]) as in WoW. relativeTo may be a frame, a frame's
--- global name, or nil for the parent.
function Region:SetPoint(point, a, b, c, d)
    local rel, relPoint, x, y = 0, point, 0, 0
    if type(a) == "table" or type(a) == "string" then
        rel = handleOf(a)
        if type(b) == "string" then relPoint, x, y = b, c or 0, d or 0 else x, y = b or 0, c or 0 end
    elseif type(a) == "number" then
        x, y = a, b or 0
    elseif a == nil then
        if type(b) == "string" then relPoint, x, y = b, c or 0, d or 0 else x, y = b or 0, c or 0 end
    end
    H:SetPoint(self.__h, point, rel, relPoint, x, y)
end

function Region:ClearAllPoints() H:ClearAllPoints(self.__h) end
function Region:SetAllPoints(rel) H:SetAllPoints(self.__h, handleOf(rel)) end
function Region:GetNumPoints() return H:GetNumPoints(self.__h) end

function Region:GetPoint(i)
    local point, rel, relPoint, x, y = H:GetPoint(self.__h, i or 1)
    if not point then return nil end
    return point, wrap(rel), relPoint, x, y
end

function Region:SetSize(w, h) H:SetSize(self.__h, w or 0, h or w or 0) end
function Region:SetWidth(w) H:SetWidth(self.__h, w) end
function Region:SetHeight(h) H:SetHeight(self.__h, h) end
function Region:GetWidth() return H:GetWidth(self.__h) end
function Region:GetHeight() return H:GetHeight(self.__h) end
function Region:GetSize() return H:GetWidth(self.__h), H:GetHeight(self.__h) end

function Region:GetRect()
    local ok, l, b, w, h = H:GetRect(self.__h)
    if not ok then return nil end
    return l, b, w, h
end

function Region:GetLeft() local l = self:GetRect(); return l end
function Region:GetBottom() local _, b = self:GetRect(); return b end
function Region:GetRight() local l, _, w = self:GetRect(); return l and l + w end
function Region:GetTop() local _, b, _, h = self:GetRect(); return b and b + h end
function Region:GetCenter()
    local l, b, w, h = self:GetRect()
    if not l then return nil end
    return l + w / 2, b + h / 2
end

-- A root frame of a replaced component (TK.ReplaceComponent) stays hidden whatever shows it; what its own code asks
-- for is kept (__want) for when the component is given back.
local function held(self)
    local c = rawget(self, "__component")
    return c ~= nil and c.replaced == true
end
function Region:Show() if held(self) then self.__want = true else H:SetShown(self.__h, true) end end
function Region:Hide()
    if held(self) then self.__want = false end
    H:SetShown(self.__h, false)
end
function Region:SetShown(shown)
    if held(self) then self.__want = shown and true or false else H:SetShown(self.__h, shown and true or false) end
end
function Region:IsShown() return H:IsShown(self.__h) end
function Region:IsVisible() return H:IsVisible(self.__h) end
function Region:SetAlpha(a) H:SetAlpha(self.__h, a or 1) end
function Region:GetAlpha() return H:GetAlpha(self.__h) end

-- ----- Texture -----

function Texture:SetTexture(key) H:SetTexture(self.__h, key or "") end
function Texture:GetTexture() return H:GetTexture(self.__h) end
function Texture:SetColorTexture(r, g, b, a) H:SetColorTexture(self.__h, r or 1, g or 1, b or 1, a or 1) end
function Texture:SetVertexColor(r, g, b, a) H:SetVertexColor(self.__h, r or 1, g or 1, b or 1, a or 1) end
function Texture:SetTexCoord(l, r, t, b) H:SetTexCoord(self.__h, l or 0, r or 1, t or 0, b or 1) end
function Texture:SetDrawLayer(layer, sub) H:SetDrawLayer(self.__h, layer or "ARTWORK", sub or 0) end
function Texture:SetRotation(rad) H:SetRotation(self.__h, rad or 0) end
function Texture:SetBlendMode() end
function Texture:SetDesaturated(on)
    self.__desaturated = on and true or false
    if on then self:SetVertexColor(0.55, 0.55, 0.55, 1) else self:SetVertexColor(1, 1, 1, 1) end
end

-- ----- FontString -----

--- Named font styles, like WoW's font objects: size, colour and flags.
TK.Fonts = {
    GameFontNormal = { 13, { 1, 0.82, 0 } },
    GameFontHighlight = { 13, { 1, 1, 1 } },
    GameFontDisable = { 13, { 0.5, 0.5, 0.5 } },
    GameFontNormalSmall = { 11, { 1, 0.82, 0 } },
    GameFontHighlightSmall = { 11, { 1, 1, 1 } },
    GameFontNormalLarge = { 16, { 1, 0.82, 0 } },
    GameFontHighlightLarge = { 16, { 1, 1, 1 } },
    NumberFontNormal = { 13, { 1, 1, 1 }, "OUTLINE" },
    NumberFontSmall = { 11, { 1, 1, 1 }, "OUTLINE" },
}

function FontString:SetText(text) H:SetText(self.__h, text ~= nil and tostring(text) or "") end
function FontString:GetText() return H:GetText(self.__h) end
function FontString:SetFormattedText(fmt, ...) self:SetText(string.format(fmt, ...)) end

-- The bitmap faces a "path" can name: the original's font ("classic") and, s6-interface-5x hook, 5.33's font 0
-- ("classic533", PackArt.Classic533Font).
local FACES = { classic = true, classic533 = true }

--- SetFont(size, flags) or WoW's SetFont(path, size, flags). The only "paths" with a meaning are the bitmap faces
--- (FACES: drawn one to one at size 12); any other keeps the open font.
function FontString:SetFont(a, b, c)
    local size, flags
    if type(a) == "number" then
        size, flags = a, b
    else
        size, flags = b, c
        H:SetFontFace(self.__h, FACES[a] and a or "")
    end
    self.__fontSize = size or 13
    H:SetFont(self.__h, self.__fontSize, flags or "")
end

function FontString:SetFontObject(name)
    local f = TK.Fonts[name] or TK.Fonts.GameFontNormal
    self:SetFont(f[1], f[3])
    self:SetTextColor(f[2][1], f[2][2], f[2][3], 1)
end

function FontString:SetTextColor(r, g, b, a) H:SetTextColor(self.__h, r or 1, g or 1, b or 1, a or 1) end
function FontString:SetJustifyH(j) H:SetJustifyH(self.__h, j or "CENTER") end
function FontString:SetJustifyV(j) H:SetJustifyV(self.__h, j or "MIDDLE") end
function FontString:SetWordWrap(on) H:SetWordWrap(self.__h, on and true or false) end
--- s6-modular-g (interfaces, 7.x's skin): extra space between lines, in the font's pixels (WoW's SetSpacing).
function FontString:SetSpacing(pixels) H:SetLineSpacing(self.__h, pixels or 0) end
function FontString:GetStringWidth() return H:GetStringWidth(self.__h) end
function FontString:GetStringHeight() return H:GetStringHeight(self.__h) end
function FontString:SetDrawLayer(layer, sub) H:SetDrawLayer(self.__h, layer or "OVERLAY", sub or 0) end
function FontString:SetVertexColor(r, g, b, a) self:SetTextColor(r, g, b, a) end

-- ----- Frame -----

function Frame:SetParent(parent) H:SetParent(self.__h, handleOf(parent)) end
function Frame:SetScale(s) H:SetScale(self.__h, s or 1) end
function Frame:GetScale() return H:GetScale(self.__h) end
function Frame:GetEffectiveScale() return H:GetEffectiveScale(self.__h) end
function Frame:SetFrameStrata(s) H:SetFrameStrata(self.__h, s or "MEDIUM") end
function Frame:SetToplevel(on) H:SetToplevel(self.__h, on and true or false) end
function Frame:IsToplevel() return H:IsToplevel(self.__h) end
function Frame:GetFrameStrata() return H:GetFrameStrata(self.__h) end
function Frame:SetFrameLevel(l) H:SetFrameLevel(self.__h, l or 0) end
function Frame:GetFrameLevel() return H:GetFrameLevel(self.__h) end
function Frame:SetID(id) H:SetID(self.__h, id or 0) end
function Frame:GetID() return H:GetID(self.__h) end
function Frame:EnableMouse(on) H:EnableMouse(self.__h, on and true or false) end
function Frame:IsMouseEnabled() return H:IsMouseEnabled(self.__h) end
function Frame:EnableMouseWheel(on) H:EnableMouseWheel(self.__h, on and true or false) end
function Frame:EnableKeyboard() end
function Frame:SetMovable(on) H:SetMovable(self.__h, on and true or false) end
function Frame:StartMoving() H:StartMoving(self.__h) end
function Frame:StopMovingOrSizing() H:StopMovingOrSizing(self.__h) end
function Frame:SetClampedToScreen(on) H:SetClampedToScreen(self.__h, on and true or false) end
function Frame:IsMouseOver() return H:IsMouseOver(self.__h) end

function Frame:RegisterForDrag(...)
    H:RegisterForDrag(self.__h, table.concat({ ... }, ","))
end

function Frame:RegisterForClicks(...)
    H:RegisterForClicks(self.__h, table.concat({ ... }, ","))
end

--- s6-ui-core (round 44): presses of these buttons ("RightButton", ...) over this frame are its own (OnMouseDown,
--- OnMouseUp), though it takes no mouse otherwise: the hover, the other buttons and the wheel go to what is under it.
--- No arguments: none. The effect icons over the world take the right button so.
function Frame:SetClaimButtons(...)
    H:SetClaimButtons(self.__h, table.concat({ ... }, ","))
end

--- s6-interface-7x (round 3): a press anywhere in this frame (or a frame in it) lets its release run the action of the
--- frame of this group under the release, however little the pointer moved; a release outside runs nothing. A menu whose
--- release chooses (7.x's say-mode menu).
function Frame:SetPicksOnRelease(on) H:SetPicksOnRelease(self.__h, on and true or false) end

--- s6-interface-7x (round 3): while this frame is shown, every key-down, repeats included, fires GLOBAL_KEY_DOWN (the
--- key's name, whether it repeats) in its place among the inputs, before the key goes on: a popup that closes on any key
--- without taking it. s6-interface-5x (Native28): live, a key-down that also reaches the game's panes (no capture, modal
--- pane, open line or box of ours took it) then fires GAME_KEY_DOWN (name, repeat, 4a's key code, modifier bits Alt 1,
--- Ctrl 2, Shift 4).
function Frame:SetWatchesKeys(on) H:SetWatchesKeys(self.__h, on and true or false) end

--- s6-interface-7x-b (round 7): while this frame is shown, the UI takes every pointer event: the wheel over the map is
--- the UI's, not a binding's (__tk:IsPointerTaken() says whether such a frame shows). A pane that takes every pointer
--- event offered to it, as 4a's ItemHelpPane (HandlePointerOrMouseEvent 0x004CCC40); the frame itself takes the presses
--- and the wheel.
function Frame:SetTakesPointer(on) H:SetTakesPointer(self.__h, on and true or false) end

--- s6-interface-7x-b (round 2): a left press accepted on this frame takes the input's capture until its left release, as
--- 4a's ScrollPane captures the mouse (ScrollPane::HandlePointerOrMouseEvent 0x0055C400, ScrollPane.cpp:125) and
--- EventDispatcher::DispatchEvent (0x004A7130) then hands every key and pointer event to the capture alone: meanwhile no
--- key and no other press reaches the game (the map, the game keys); the frame keeps its own moves and its release. A
--- scroll bar's track and thumb. WIRE: without it a game key pressed while the bar is held acts (m's 7C) and a right
--- press reaches the map (a look); with it on a frame 4a's never captures, those keys and presses are lost. Either
--- changes what the server sees.
function Frame:SetCapturesPress(on) H:SetCapturesPress(self.__h, on and true or false) end

--- s6-interface-7x-b (round 2): a double click's second press over this frame goes to what is under it, as 4a's panes that
--- act on the left press (event type 1) alone let the double press (type 2) fall through (MiniMapButtonPane::
--- HandlePointerOrMouseEvent 0x005036A0, MapNamePane.cpp:189; ScrollPane's 0x0055C400; ChattingModifyHeightPane's
--- 0x00480890); a claiming frame claims single presses only. WIRE: over the map view the double press is then the map's
--- press; taken here, the map loses it, and the minimap button would arm again for a second 7C. Either changes what the
--- server sees.
function Frame:SetPassesDoubles(on) H:SetPassesDoubles(self.__h, on and true or false) end

--- s6-input (round 51, Astra's self-review 51-2): a frame claiming a button takes every release over it, not only its
--- own press's (4a's MiniMapButtonPane::HandlePointerOrMouseEvent 0x005036A0 case 3; ScrollPane and
--- ChattingModifyHeightPane pass another press's release on: TK.ReleaseTarget). WIRE: a release it takes reaches no
--- control under it, so changing it changes what the server sees.
function Frame:SetTakesEveryRelease(on) H:SetTakesEveryRelease(self.__h, on and true or false) end

function Frame:SetScript(script, fn)
    self.__scripts = self.__scripts or {}
    if script == "OnUpdate" and self.__updatePeriod then
        -- s6-ui-core (round 101, T11 step 2): the host was counting a Throttled script's wait; what it had left goes back
        -- to that script, which counts on from there if it keeps running (wrapped by HookScript, say)
        self.__updateLeft, self.__updateLeftOf = H:GetUpdateWait(self.__h), self.__scripts.OnUpdate
    end
    self.__scripts[script] = fn
    if script == "OnUpdate" then self.__updatePeriod = nil end -- the host drops the period with it (UIFrame.SetScriptFlag)
    H:SetScriptFlag(self.__h, script, fn ~= nil)
end

--- s6-ui-core (round 101, the graphics plan's T11 step 2): the OnUpdate script is called by the host only every period
--- seconds, the next time in wait; a new SetScript("OnUpdate") drops it. For TK.Util.Throttled, which hands its countdown
--- over; drawing and polling only (no wire-timed script has a period).
function Frame:SetUpdatePeriod(period, wait)
    self.__updatePeriod = period
    H:SetUpdatePeriod(self.__h, period, wait)
end

--- s6-ui-core (round 101, T11 step 3): the OnUpdate script is called by the host only on the frames where one of the
--- named values changed since its last call, at the same point of the frame, and on its first frame shown (with a period,
--- on a due frame only). The names (one argument each, so an XML <do SetUpdateWhen="world, position"/> gives them too):
--- "position" (__tk:GetLocation's), "world" (the units, the player's values, the target: the world's snapshot), "line"
--- (the logic's line and whether input is live), "look" (a look and the self-look presses), "minimap" (the minimap
--- requests), "shown" (any frame shown or hidden), "saymode". For a script that only compares those values; when
--- something else it draws from changes, calling this again has the script called on its next frame. Set after
--- SetScript("OnUpdate"), which drops it. Drawing and watching only: no wire-timed script uses it.
function Frame:SetUpdateWhen(...)
    H:SetUpdateWhen(self.__h, table.concat({ ... }, ","))
end

function Frame:GetScript(script)
    return self.__scripts and self.__scripts[script]
end

function Frame:HookScript(script, fn)
    local old = self:GetScript(script)
    if not old then return self:SetScript(script, fn) end
    self:SetScript(script, function(...)
        old(...)
        fn(...)
    end)
end

function Frame:RegisterEvent(event)
    eventFrames[event] = eventFrames[event] or {}
    eventFrames[event][self] = true
end

function Frame:UnregisterEvent(event)
    if eventFrames[event] then eventFrames[event][self] = nil end
end

function Frame:UnregisterAllEvents()
    for _, set in pairs(eventFrames) do set[self] = nil end
end

function Frame:IsEventRegistered(event)
    return eventFrames[event] ~= nil and eventFrames[event][self] == true
end

function Frame:CreateTexture(name, layer, template, sub)
    local t = wrap(H:CreateTexture(self.__h, name or "", layer or "ARTWORK", sub or 0))
    t.__name = name
    if name and name ~= "" then _G[name] = t end
    applyTemplates(t, template)
    return t
end

function Frame:CreateFontString(name, layer, template, sub)
    local fs = wrap(H:CreateFontString(self.__h, name or "", layer or "OVERLAY", sub or 0))
    fs.__name = name
    if name and name ~= "" then _G[name] = fs end
    if template and TK.Fonts[template] then
        fs:SetFontObject(template)
    else
        fs:SetFontObject("GameFontNormal")
        applyTemplates(fs, template)
    end
    return fs
end

--- A simplified SetBackdrop: { bg = {r,g,b,a}, edge = {r,g,b,a}, edgeSize = n, bgFile = key, edgeFile = key,
--- inset = n }. nil removes it. s6-ui-core (round 49, Modern's panel finish): band = { height = n, color = {r,g,b,a} }, a
--- wash of light at the top inside the edge, fading downwards (a window's title area); its opacity follows the
--- background's, so a see-through panel's band fades with it.
function Frame:SetBackdrop(b)
    if not b then
        if self.__bg then self.__bg:Hide() end
        if self.__edge then self.__edge:Hide() end
        if self.__band then self.__band:Hide() end
        return
    end
    local inset = b.inset or 0
    if not self.__bg then
        self.__bg = self:CreateTexture(nil, "BACKGROUND", nil, -8)
    end
    self.__bg:ClearAllPoints()
    self.__bg:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -inset)
    self.__bg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset, inset)
    self.__bg:SetTexture(b.bgFile or "tk:panel")
    if b.band then
        if not self.__band then self.__band = self:CreateTexture(nil, "BACKGROUND", nil, -7) end
        self.__band:ClearAllPoints()
        self.__band:SetPoint("TOPLEFT", self, "TOPLEFT", inset + 3, -inset - 3)
        self.__band:SetPoint("TOPRIGHT", self, "TOPRIGHT", -inset - 3, -inset - 3)
        self.__band:SetHeight(b.band.height)
        self.__band:SetTexture("tk:gradient-v")
        self.__bandColor = b.band.color
        self.__band:Show()
    elseif self.__band then
        self.__band:Hide()
        self.__bandColor = nil
    end
    local bg = b.bg or { 0, 0, 0, 0.8 }
    self:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    self.__bg:Show()
    if b.edge ~= false then
        if not self.__edge then
            self.__edge = self:CreateTexture(nil, "BORDER", nil, -8)
            self.__edge:SetAllPoints(self)
        end
        self.__edge:SetTexture(b.edgeFile or "tk:border")
        local e = b.edge or { 0.6, 0.6, 0.6, 1 }
        self.__edge:SetVertexColor(e[1], e[2], e[3], e[4] or 1)
        self.__edge:Show()
    elseif self.__edge then
        self.__edge:Hide()
    end
end

function Frame:SetBackdropColor(r, g, b, a)
    -- s6-ui-settings (round 4), the shared panel style: the colour is kept (so the panel is drawn again when its finish
    -- changes), and a panel with a finish draws its background at the opacity the finish gives (s6-devtools round 5,
    -- s6-optimize's audit of round 53, item 4: the skin's see-through finish, set by TK.UI.HudPanel and TK.UI.InnerPanel).
    self.__bgColor = { r, g, b, a or 1 }
    if self.__finish then a = self.__finish(self, a or 1) end
    if self.__bg then self.__bg:SetVertexColor(r, g, b, a or 1) end
    local band = self.__bandColor
    if band then self.__band:SetVertexColor(band[1], band[2], band[3], (band[4] or 1) * (a or 1)) end
end

function Frame:SetBackdropBorderColor(r, g, b, a)
    if self.__edge then self.__edge:SetVertexColor(r, g, b, a or 1) end
end

-- ----- Button -----

local function textureArg(button, arg, layer)
    if type(arg) == "table" then return arg end
    local t = button:CreateTexture(nil, layer or "ARTWORK")
    t:SetAllPoints(button)
    t:SetTexture(arg)
    return t
end

function Button:SetNormalTexture(t)
    self.__normal = textureArg(self, t, "ARTWORK")
    H:SetButtonTexture(self.__h, "Normal", self.__normal.__h)
end

function Button:SetPushedTexture(t)
    self.__pushed = textureArg(self, t, "ARTWORK")
    H:SetButtonTexture(self.__h, "Pushed", self.__pushed.__h)
end

function Button:SetHighlightTexture(t)
    self.__highlight = textureArg(self, t, "HIGHLIGHT")
    H:SetButtonTexture(self.__h, "Highlight", self.__highlight.__h)
end

function Button:SetDisabledTexture(t)
    self.__disabled = textureArg(self, t, "ARTWORK")
    H:SetButtonTexture(self.__h, "Disabled", self.__disabled.__h)
end

function Button:GetNormalTexture() return self.__normal end
function Button:GetPushedTexture() return self.__pushed end
function Button:GetHighlightTexture() return self.__highlight end

function Button:GetFontString()
    if not self.__label then
        local fs = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("CENTER", self, "CENTER", 0, 0)
        self.__label = fs
        H:SetButtonLabel(self.__h, fs.__h)
    end
    return self.__label
end

function Button:SetFontString(fs)
    self.__label = fs
    H:SetButtonLabel(self.__h, fs.__h)
end

function Button:SetText(text) self:GetFontString():SetText(text) end
function Button:GetText() return self.__label and self.__label:GetText() or nil end

function Button:SetNormalFontColor(r, g, b, a)
    self:GetFontString()
    H:SetButtonLabelColor(self.__h, r, g, b, a or 1)
end

function Button:Enable() H:SetEnabled(self.__h, true) end
function Button:Disable() H:SetEnabled(self.__h, false) end
function Button:SetEnabled(on) H:SetEnabled(self.__h, on and true or false) end
function Button:IsEnabled() return H:IsEnabled(self.__h) end
function Button:Click(button) H:Click(self.__h, button or "LeftButton") end

function Button:SetButtonState(state)
    H:SetButtonPushed(self.__h, state == "PUSHED")
end

-- WoW's pair of SetButtonState: "PUSHED" while SetButtonState holds the pushed look, else "NORMAL".
function Button:GetButtonState()
    return H:IsButtonPushed(self.__h) and "PUSHED" or "NORMAL"
end

-- ----- CheckButton -----

function CheckButton:SetChecked(on) H:SetChecked(self.__h, on and true or false) end
function CheckButton:GetChecked() return H:GetChecked(self.__h) end

function CheckButton:SetCheckedTexture(t)
    self.__checked = textureArg(self, t, "OVERLAY")
    H:SetButtonTexture(self.__h, "Checked", self.__checked.__h)
end

-- ----- StatusBar -----

function StatusBar:SetMinMaxValues(lo, hi) H:SetMinMaxValues(self.__h, lo or 0, hi or 1) end
function StatusBar:GetMinMaxValues()
    local _, lo, hi = H:GetMinMaxValues(self.__h)
    return lo, hi
end
function StatusBar:SetValue(v) H:SetValue(self.__h, v or 0) end
function StatusBar:GetValue() return H:GetValue(self.__h) end
function StatusBar:SetStatusBarColor(r, g, b, a) H:SetStatusBarColor(self.__h, r or 1, g or 1, b or 1, a or 1) end
function StatusBar:SetStatusBarTexture(key) H:SetStatusBarTexture(self.__h, key or "tk:bar") end
function StatusBar:GetStatusBarTexture() return wrap(H:GetStatusBarTexture(self.__h)) end
function StatusBar:SetOrientation(o) H:SetOrientation(self.__h, o or "HORIZONTAL") end
function StatusBar:SetReverseFill(on) H:SetReverseFill(self.__h, on and true or false) end

-- ----- Slider -----

Slider.SetMinMaxValues = StatusBar.SetMinMaxValues
Slider.GetMinMaxValues = StatusBar.GetMinMaxValues
Slider.SetValue = StatusBar.SetValue
Slider.GetValue = StatusBar.GetValue
function Slider:SetValueStep(step) H:SetValueStep(self.__h, step or 0) end
function Slider:SetObeyStepOnDrag() end
function Slider:Enable() H:SetEnabled(self.__h, true) end
function Slider:Disable() H:SetEnabled(self.__h, false) end
function Slider:SetEnabled(on) H:SetEnabled(self.__h, on and true or false) end
function Slider:IsEnabled() return H:IsEnabled(self.__h) end

-- ----- EditBox -----

function EditBox:SetText(text) H:SetText(self.__h, text ~= nil and tostring(text) or "") end
function EditBox:GetText() return H:GetText(self.__h) or "" end
function EditBox:GetNumber() return tonumber(self:GetText()) or 0 end
function EditBox:SetFocus() H:SetFocus(self.__h) end
function EditBox:ClearFocus() H:ClearFocus(self.__h) end
function EditBox:HasFocus() return H:HasFocus(self.__h) end
function EditBox:SetNumeric(on) H:SetNumeric(self.__h, on and true or false) end
function EditBox:SetMaxLetters(n) H:SetMaxLetters(self.__h, n or 0) end
function EditBox:GetMaxLetters() return H:GetMaxLetters(self.__h) end
-- s6-rules-dialogs (round 36): WoW's SetCursorPosition. Round 37: 4a's money edit, the trade's field (UIEditField: no
-- selection on focus, digits appended and nothing else, the pointer swallowed).
function EditBox:SetCursorPosition(p) H:SetCursorPosition(self.__h, p or 0) end
function EditBox:SetAppendDigitsOnly(on) H:SetAppendDigitsOnly(self.__h, on and true or false) end
function EditBox:SetPassword(on) H:SetPassword(self.__h, on and true or false) end
function EditBox:SetAutoFocus() end
function EditBox:SetFontSize(size) H:SetFont(self.__h, size or 13, "") end
function EditBox:SetJustifyH(j) H:SetJustifyH(self.__h, j or "LEFT") end
function EditBox:Enable() H:SetEnabled(self.__h, true) end
function EditBox:Disable() H:SetEnabled(self.__h, false) end
function EditBox:SetEnabled(on) H:SetEnabled(self.__h, on and true or false) end
function EditBox:SetMultiLine(on) H:SetEditMultiLine(self.__h, on and true or false) end -- s6-rules-dialogs
-- s6-interface-7x (round 2): a multi-line box's text scroll, in pixels, as a ScrollFrame's (7.x's scroll bar beside it)
function EditBox:SetVerticalScroll(v) H:SetVerticalScroll(self.__h, v or 0) end
function EditBox:GetVerticalScroll() return H:GetVerticalScroll(self.__h) end
function EditBox:GetVerticalScrollRange() return H:GetVerticalScrollRange(self.__h) end
function EditBox:SetScrollLineStep(pixels) H:SetScrollLineStep(self.__h, pixels or 0) end -- whole lines (UIEditBox)

-- ----- ScrollFrame -----

function ScrollFrame:SetScrollChild(child) H:SetScrollChild(self.__h, handleOf(child)) end
function ScrollFrame:GetScrollChild() return wrap(H:GetScrollChild(self.__h)) end
function ScrollFrame:SetVerticalScroll(v) H:SetVerticalScroll(self.__h, v or 0) end
function ScrollFrame:GetVerticalScroll() return H:GetVerticalScroll(self.__h) end
function ScrollFrame:GetVerticalScrollRange() return H:GetVerticalScrollRange(self.__h) end

-- ----- Cooldown -----

function Cooldown:SetCooldown(start, duration) H:SetCooldown(self.__h, start or 0, duration or 0) end
function Cooldown:Clear() H:ClearCooldown(self.__h) end
function Cooldown:GetCooldownTimes()
    local _, start, duration = H:GetCooldownTimes(self.__h)
    return start, duration
end
function Cooldown:SetDrawSwipe(on) H:SetDrawSwipe(self.__h, on and true or false) end
function Cooldown:SetDrawEdge(on) H:SetDrawEdge(self.__h, on and true or false) end
function Cooldown:SetHideCountdownNumbers(on) H:SetHideCountdownNumbers(self.__h, on and true or false) end
function Cooldown:SetSwipeColor(r, g, b, a) H:SetSwipeColor(self.__h, r or 0, g or 0, b or 0, a or 0.7) end
function Cooldown:SetCountdownFontSize(size) H:SetCountdownFontSize(self.__h, size or 16) end

-- ----- WorldView -----

-- s6-world-view (round 29): the outer area's saturation and Expand Live View; the scale the settings worked out and the
-- smoothing where it enlarges.
function WorldView:SetWorldView(cols, rows, dim, saturation, liveBand, scale, smoothing)
    H:SetWorldView(self.__h, cols or 17, rows or 15, dim or 0.2, saturation or 1, liveBand and true or false, scale or 1, smoothing or "none")
end

function WorldView:SetOriginalColour16(on) H:SetWorldViewColour16(self.__h, on and true or false) end
function WorldView:SetOriginalOptions(shadows, seeThrough, objectTransparency)
    H:SetWorldViewOptions(self.__h, shadows and true or false, seeThrough and true or false, objectTransparency and true or false)
end
-- s6-world-view: the far view's extras (plan 5.10)
function WorldView:SetFarView(objects, rememberItems, confirmMs, maxAgeMinutes)
    H:SetWorldViewFarView(self.__h, objects and true or false, rememberItems and true or false, confirmMs or 2000, maxAgeMinutes or 10)
end
function WorldView:SetMapEffects(on) H:SetWorldViewMapEffects(self.__h, on and true or false) end -- s6-world-view (O-03)
-- s6-world-view (round 36): "Add Border to Zone" and its colour, 0-255 a channel; round 37: its opacity, 0-100 %
function WorldView:SetZoneBorder(on, r, g, b, opacity) H:SetWorldViewZoneBorder(self.__h, on and true or false, r or 211, g or 211, b or 211, opacity or 50) end
-- s6-effects-c (round 8): See-Through's child, Fade Over the Player (drawing only)
function WorldView:SetFadeOver(on) H:SetWorldViewFade(self.__h, on and true or false) end
function WorldView:GetMapTitle() return H:GetWorldViewTitle(self.__h) end

function WorldView:GetNaturalSize()
    local _, w, h = H:GetWorldViewSize(self.__h)
    return w, h
end

-- ----- UIParent -----

UIParent = wrap(H:UIParent())
UIParent.__name = "UIParent"
