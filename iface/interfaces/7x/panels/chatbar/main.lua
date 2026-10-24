-- s6-modular-g (interfaces, phase 5, round 14): 7.x's chat bar, the original's ChattingHandlePane at (74, 727)-(740, 751)
-- of the 7.x screen, in the frame layer: its four regions (GetChatButtonRect) are Back to Talk (0, 4)-(19, 21), the typing
-- area (21, 0)-(624, 24), the backdrop mode (630, 4)-(649, 21) and the chat switch (649, 4)-(668, 21); each button is
-- CHATBUTT.EPF in CHATBUTT.PAL, frame look x 3 + its column from the first nine frames while its setting is on, the last
-- nine while it is off (OnPaint), look 1 under the pointer and 2 while pressed. The open line (a LineInputPane, at (100, 733)-(693, 745)) is
-- drawn on it: its prompt in 0x80, its text after it from the prompt's width less 2, with its caret. The say-mode button
-- beside it (ChattingVarietyPane, (10, 727)) and its menu are s6-interface-7x's (panels/saymode).
-- s6-ui-core (round 85): the XML twin's scripts; its frames, their places and pictures are main.xml's (core/xml.md).
--
-- Wire: the line, its keys and what Enter sends are the chat rules' (TK.Core.Rules.Chat.ChatRules: 0E, 19), as with
-- Modern's chat bar; this only draws the line and passes the presses on through the game layer's chat (TK.Game.Chat,
-- core/game/chat.lua; s6-interface-5x round 12, separation step 3): a left press on the typing area while no line or
-- prompt is open runs the rules' chat:current (the say mode's line, or Talk's with Back to Talk:
-- UserPane::OpenInputPaneForCurrentSayMode), in the press's own record (TypingPress); Back to Talk turns over on its
-- release over it (ChattingHandlePane::HandlePointerOrMouseEvent) and goes to the rules (SetBackToTalk). Changing which
-- press opens the line, or when, changes what the client sends. Offline (the mock world) the bar draws the game layer's
-- line itself (its own box, round 12: it borrowed Modern's chat frame's before), and it draws every rules' prompt, the
-- one-key ones too, as 7.5.2 draws every LineInputPane on its chat bar (round 12, G3; TK.Game.Prompts), so Classic
-- Commands' prompt display draws no second copy (W2).

local C = TK.GetComponent("7x.chatbar")
local H = __tk
local S = require("interfaces.7x.skin")
local Screen = require("interfaces.screen")
local G = TK.Game.Chat

local L = TK.Xml.Data("main.xml")
local LINE_X, LINE_Y, LINE_RIGHT = L.LINE.x, L.LINE.y, L.LINE.right

local function live() return H:IsLiveInput() end

-- 4a ChattingHandlePane::HandlePointerOrMouseEvent (0x00481D60): these settings change on the matching release.
-- Back to Talk affects the next chat command; the other two are local presentation. Changing this path changes
-- what the server sees. Settings belong to the shared game layer; these are only 7.x's controls and artwork.
local SETTINGS = {
    backToTalk = { on = G.BackToTalk, release = function() G.SetBackToTalk(not G.BackToTalk()) end },
    backdrop = { on = function() return G.BackdropMode() ~= 0 end, release = G.CycleBackdrop },
    log = { on = G.LogEnabled, release = G.ToggleLog },
}

--- A button's picture: CHATBUTT frame look x 3 + column, from the last nine frames while its setting is off.
local function drawButton(f, b)
    local a = L.ART
    local frame = b.look * 3 + b.column + (b.on() and 0 or a.off)
    b.tex = S.Picture(f, b.tex, a.file, frame, a.palette, b.x, b.y, "ARTWORK")
end

-- the scripts main.xml names
local scripts = {}

function scripts.Own(f)
    C:Own(f)
    C.frame = f
    f.buttons = {}
end

--- A button's state (its setting's switch and release, its look) as its frame's b, drawn.
function scripts.Button(btn)
    local f, a = btn:GetParent(), btn.art
    local s = SETTINGS[a.setting]
    local b = { x = a.x, y = a.y, column = a.column, look = 0, on = s.on, release = s.release, button = btn }
    btn.b = b
    f.buttons[#f.buttons + 1] = b
    drawButton(f, b)
end

-- Shared G.BarButtonArms matches 4a's ChattingHandlePane::HandlePointerOrMouseEvent (0x00481D60): field_119/11A/11B
-- require a single left press on this same button before its release can act. Changing this changes Back to Talk and
-- the later chat packet the server sees.
function scripts.ButtonDown(btn, button, double)
    if not G.BarButtonArms(button, double) then return end
    local f, b = btn:GetParent(), btn.b
    b.look = 2
    b.held = true
    f.heldButton = b
    drawButton(f, b)
end

-- s6-input (round 51, Astra's final review of round 50, the class of its P2): the release acts only while the
-- button is the frame on top under the pointer (TK.ReleaseTarget), not by its place, so a release over another
-- interface's frame lying over it is that frame's (ChattingHandlePane::HandlePointerOrMouseEvent sees only its
-- own regions). Back to Talk chooses the line the next typing press opens, so changing this changes what the
-- client sends after it.
-- Shared G.BarButtonReleaseActs keeps 4a's armed left release rule (0x00481D60); changing it changes what the server sees.
function scripts.ButtonUp(btn, button)
    local b = btn.b
    if G.BarButtonReleaseActs(button, b.released) and TK.ReleaseTarget(button) == btn and b.release then b.release() end
end

function scripts.ButtonEnter(btn)
    local f, b = btn:GetParent(), btn.b
    b.look = f.heldButton and (b.held and 2 or 0) or 1
    drawButton(f, b)
end

function scripts.ButtonLeave(btn)
    local b = btn.b
    b.look = 0
    drawButton(btn:GetParent(), b)
end

function scripts.FollowSettings(f)
    TK.On("TK_CHAT_SETTINGS", function()
        for _, b in ipairs(f.buttons) do drawButton(f, b) end
        f:SetUpdateWhen("line", "shown") -- s6-ui-core (round 101, T11 step 3): DrawLine on the next frame (Back to Talk)
    end)
end

-- the typing area: the rules' chat:current while no line or prompt is open. WIRE: above (TypingPress)
function scripts.TypingPress(typing, button)
    G.TypingPress(typing, button)
end

-- the offline line (the mock world): the game layer's, on this bar while it shows (TK.Game.Chat.ProvideLine, which
-- drives the box; Modern's chat frame leaves its own bar out meanwhile): its prompt where the live line's is drawn,
-- the box after it in font 0 and 0x80 with no frame, as the line's text (the edits' look of 7.x's dialogs, X.Edit)
function scripts.LineBox(box)
    H:SetFontFace(box.__h, "classic")
    local r, g, b = S.Colour(S.TEXT)
    H:SetTextColor(box.__h, r, g, b, 1)
    H:SetTextInsets(box.__h, 0, 0, 0, 0)
    H:SetLineSpacing(box.__h, -2)
end

function scripts.ProvideLine(f)
    G.ProvideLine("7x.chatbar", {
        bar = true,
        shown = function() return f:IsShown() end,
        box = f.box,
        prompt = function(text)
            local x = S.PenText(f.offlinePrompt, f, text, LINE_X, LINE_Y + 12, S.TEXT)
            f.offlinePrompt:SetShown(text ~= "")
            f.box:ClearAllPoints()
            f.box:SetPoint("TOPLEFT", f, "TOPLEFT", x - 2, -LINE_Y)
            f.box:SetSize(LINE_RIGHT - (x - 2), 12)
        end,
    })
    -- the rules' prompts, every kind, are drawn on this bar while it shows (DrawLine)
    TK.Game.Prompts.ProvideHost("7x.chatbar", function() return f:IsShown() end, true)
end

-- s6-ui-core (round 101, T11 step 3): main.xml has DrawLine called only on the frames where the line (or live input) or a
-- frame's shown state changed, at the same point of the frame as when it ran every frame, and after TK_CHAT_SETTINGS
-- (Back to Talk's picture). WIRE: the typing area's action it sets (G.UpdateTyping, 4a's
-- UserPane::OpenInputPaneForCurrentSayMode on a press while no line is open) follows the line's owner alone, which "line"
-- watches, so a press finds the same action at every frame; changing what DrawLine watches can change which line a press
-- opens, which the server sees.
function scripts.Update() C:DrawLine() end

function scripts.Register(f)
    C.entry = Screen.Register(f, "7x.chatbar", "7.x Chat Bar", function() return C:DB().enabled == true end)
end

function C:OnEnable()
    TK.Xml.Load("main.xml", { scripts = scripts })
end

--- Live: the rules' open line (the chat's, or a prompt's) with its caret, and the typing area's action while none is open;
--- drawn when it changes. A one-key prompt shows its prompt only: CharInputPane's constructor (0x004F28A0) takes its field
--- out of the focus, so no caret. Back to Talk's picture follows its setting.
function C:DrawLine()
    local f = self.frame
    if not (f and f:IsShown()) then return end
    if f.buttons[1].on() ~= f.talkOn then
        f.talkOn = f.buttons[1].on()
        drawButton(f, f.buttons[1])
    end
    if not live() then return end
    local owner = H:GetLineOwner()
    if owner == "Chat" or owner == "Prompt" then
        local line = H:GetLine()
        if line.Version ~= f.version then
            f.version = line.Version
            local x = S.PenText(f.prompt, f, line.Label, LINE_X, LINE_Y + 12, S.TEXT)
            if owner == "Prompt" and H:GetLineKind() == "Char" then
                f.text:Hide()
            else
                S.PenText(f.text, f, TK.Util.WithCaret(line.Text, line.SelectionEnd), x - 2, LINE_Y + 12, S.TEXT)
            end
        end
    elseif f.version ~= -1 then
        f.version = -1
        f.prompt:Hide()
        f.text:Hide()
    end
    G.UpdateTyping(f.typing)
end

--- At the original's place on the scaled 7.x screen (unless moved), at the screen's scale times its own; in the game only.
function C:Layout() Screen.PlacePanel(self, 1024, 768, L.PLACE[1], L.PLACE[2]) end

function C:ApplySettings() self:Layout() end

Screen.Follow(C, "Layout")
-- 4a clears all three pressed flags on every left release (ChattingPane.cpp:1298-1300), even outside the bar.
-- GLOBAL_MOUSE_UP runs before the target's script: retain this release's origin for OnMouseUp, then clear the held
-- state. A swallowed release has no script and cannot act. No capture is added; changing this path changes the wire.
TK.On("GLOBAL_MOUSE_UP", function(_, button)
    local f = C.frame
    if button ~= "LeftButton" or not f then return end
    f.heldButton = nil
    for _, b in ipairs(f.buttons) do
        b.released, b.held = b.held, false
        b.look = b.button:IsMouseOver() and 1 or 0
        drawButton(f, b)
    end
end)
