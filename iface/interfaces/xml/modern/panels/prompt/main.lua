-- Modern's prompt line (s6-modular-g round 16, separation step 7; docs/development/interface-separation.md 4.3): the
-- two lines a prompt is drawn on, moved unchanged from Classic Commands (components/classic), which keeps the prompts'
-- logic:
--   TKRulesPrompt   live: the logic's line while it is a prompt's ("Drop what?") that no interface's chat draws
--                   (TK.Game.Prompts.Drawn: Modern's chat frame and 5.x's chat draw a Text prompt's line, 7.x's chat
--                   bar every prompt, as 4a's LineInputPane is drawn on the chat bar; s6-ui-chat, W2);
--   TKClassicPrompt offline (the mock world): Classic Commands' own one-key prompt, told by TK_CLASSIC_PROMPT (its
--                   text, or nil when it closes).
-- Drawing only: nothing is sent. A live prompt's keys are the rules' and an offline one's Classic's key layer, whether
-- this line shows or not.
-- s6-ui-core (round 85): the XML twin's scripts; the lines and the watcher are main.xml's templates (core/xml.md).

local C = TK.GetComponent("prompt")
local E = require("interfaces.modern.elements")
local H = __tk

local function on() return C:DB().enabled ~= false end

-- the scripts main.xml names
local scripts = {}

-- the lines and the watcher are the panel's own (they go when it is turned off)
function scripts.Own(f) C:Own(f) end

local ui = TK.Xml.Load("main.xml", { scripts = scripts, elements = E })

--- One prompt line, hidden: the bar a prompt's text is drawn on, above the chat (both lines are alike).
local function makeBar(name) return ui:New("Bar", nil, name) end

-- ----- Classic Commands' own prompt (offline) -----

local bar
-- The open prompt's text, nil when none: shown again when the panel is turned back on. s6-interface-5x (round 14): this
-- file is loaded afresh when the panel is turned on (step 11), so it starts from Classic Commands' open prompt.
local pending = TK.GetComponent("classic").promptText

--- Classic's prompt opened (its text) or closed (nil).
local function classicPrompt(text)
    pending = text
    if not text then
        if bar then bar:Hide() end
        return
    end
    if not bar then bar = makeBar("TKClassicPrompt") end
    bar.text:SetText(text)
    bar:SetShown(on())
end

TK.On("TK_CLASSIC_PROMPT", function(_, text) classicPrompt(text) end)

-- ----- the rules' prompt, shown (live) -----

local view

--- s6-ui-chat: a prompt is drawn on the chat bar that shows, where the original draws every LineInputPane, when that
--- chat draws its kind; here otherwise. s6-interface-5x (round 12, separation step 3 and G3): the chats say what they draw
--- to the game layer (TK.Game.Prompts), so none is drawn here a second time (W2).
local function promptHere()
    if not on() or not H:IsLiveInput() or H:GetLineOwner() ~= "Prompt" then return false end
    return not TK.Game.Prompts.Drawn(H:GetLineKind())
end

--- The watcher: shows the rules' line when a prompt it draws comes.
function scripts.Watch()
    if promptHere() and not view:IsShown() then
        view.version = -1
        view:Show()
    end
end

--- The logic's line when it is a prompt's: its label, and a line prompt's text with the caret.
function C:OnEnable()
    view = makeBar("TKRulesPrompt")
    view.version = -1
    view:SetScript("OnUpdate", function()
        if not promptHere() then
            view:Hide()
            return
        end
        local line = H:GetLine()
        if line.Version == view.version then return end
        view.version = line.Version
        view.text:SetText(line.Label .. " " .. TK.Util.WithCaret(line.Text, line.SelectionEnd))
    end)
    -- Shown by a frame that runs while the panel is on: the prompt comes from the logic, not from a key of ours. Off
    -- (7.x's and 5.x's first profiles), it is hidden, so the panel neither runs nor shows anything.
    C.watch = ui:New("Watch")
    C.watch:SetShown(on())
    if pending then classicPrompt(pending) end -- (loaded while Classic's prompt is open)
end

--- Turned off, both lines and the watcher hide (the rules' line hides itself on its next frame); turned on, an open
--- prompt shows again.
function C:ApplySettings()
    if bar then bar:SetShown(on() and pending ~= nil) end
    if C.watch then C.watch:SetShown(on()) end
end
