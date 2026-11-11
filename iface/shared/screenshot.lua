-- The screenshot keys (head note 28; the original's EventDispatcher::DispatchEvent): Scroll Lock saves a PNG, with
-- Shift a BMP; Ctrl+Shift+3 a BMP and Ctrl+Shift+4 a PNG. In a live session those are 4a's fixed keys, which the logic's
-- dispatcher takes before anything else: the picture, then its proof (83) inside that event (C#'s SessionCalls.TakeLive).
-- Offline, and on any other key bound to the commands SCREENSHOT and SCREENSHOTBMP (head note 37), this file takes the
-- picture, with no proof. The picture is saved once the frame is drawn, in the user folder's screenshots.

local H = __tk

local S = {}
TK.Screenshot = S

-- The original's own keys: live they are the dispatcher's, so a binding of theirs runs nothing here.
S.ORIGINAL = { SCROLLLOCK = true, ["SHIFT-SCROLLLOCK"] = true, ["CTRL-SHIFT-3"] = true, ["CTRL-SHIFT-4"] = true }

--- A key press: true when it was a screenshot key (then it goes no further).
function S:OnKey(key, down)
    -- WIRE: both captures own screenshot keys before 4a's EventDispatcher::DispatchEvent (0x004A7130) shortcut
    -- and ScreenPane::SendScreenshotProofPacket (0x00558240, 83). Outside capture the shortcut stays unchanged;
    -- changing this changes what the server sees. The Lua hook must leave Edit Mode its key too.
    if TK.KeyBindMode.capture or TK.KeyBindMode.active then return false end
    local command = TK.Bindings:Map()[key]
    if command ~= "SCREENSHOT" and command ~= "SCREENSHOTBMP" then return false end
    if down and not (H:IsLiveInput() and self.ORIGINAL[key]) then H:TakeScreenshot(command == "SCREENSHOTBMP") end
    return true
end

-- The line (live 2026-10-01, C10): 4a's ScreenPane adds "Screen Captured. 'MyDocuments\NexusTK\ScreenShots\NAME'" to the
-- chat, in palette colour 143 outlined in 1, while the chat pane exists (in the game; ScreenPane.cpp:426-433). Ours keeps
-- the pictures in the client's own folder, so the line names that one. It shows even with Shift held (the BMP key), where
-- 4a's chat keeps its view (Astra's review of round 27).
TK.On("TK_SCREENSHOT", function(_, file, shown)
    if not TK.GameState:InWorld() then return end
    -- s6-interface-5x: by the client's lines' event (TK_CLIENT_MESSAGE, the game layer's chat lines), so every
    -- interface's chat has it
    TK.FireEvent("TK_CLIENT_MESSAGE", "Screen Captured. '" .. tostring(shown or file) .. "'",
        TK.Chat:PaletteRGB(143) or TK.Chat.colours.say, TK.Chat:PaletteRGB(1), true)
end)
