-- s6-rules-dialogs: the alerts (AlertPane and its kinds, behaviour.md 1.3): the message (the model's text, or the
-- original's string by its id), one or two buttons (1 the primary: Enter; 2 the secondary: Esc), no focus at the
-- opening. The lost connection's three (D-79 to D-81), the menu's and the game's URL alert (S-20, D-54), the quit
-- dialog (D-82), the trade's result (D-21), the server's message (D-83) and the bulletin replies all are alerts.
--
-- s6-modular-g (interfaces): the window's size and where its parts sit are the look's (C.look.Alert); this file
-- keeps what the alert does.
--
-- Wire: AlertPane::OnControlCommand 0x004A0580 (its kinds' by the same indexes; ExchangeAlertPane's 0x004B0820): 1 the
-- primary, 2 the secondary, which the model answers or leaves silent by the alert's kind; changing an index changes
-- what the server sees.

local C = TK.GetComponent("dialogs")
local K = C.kit
local W = TK.UI

local TITLES = {
    ConnectionClosedDialog = "Connection", ReconnectDialog = "Connection", CopyWindow = "Connection",
    QuitDialog = "Quit", UrlAlertPane = "Notice", ExchangeAlertPane = "Trade",
}

local Alert = { look = "Alert" }

function Alert.build()
    local L = C.look.Alert
    local win = K.Window(L.width, L.height, "")
    win.text = K.Block(win, 13, "CENTER")
    win.url = W.Label(win, "", 12, { 0.55, 0.75, 1 }, "CENTER")
    win.b1 = K.Button(win, 1, "OK", L.button, L.buttonHeight)
    win.b2 = K.Button(win, 2, "Cancel", L.button, L.buttonHeight)
    L.place(win)
    return win
end

function Alert.update(win, view)
    local L = C.look.Alert
    local c = view.contents
    win.title:SetText(TITLES[view.name] or "")
    local text = K.Text(c.text)
    if text == "" and c.stringId then text = K.String(c.stringId, "#" .. c.stringId) end
    win.text:SetText(text)
    win.url:SetText(c.url or "")
    win.url:SetShown(c.url ~= nil)
    L.fit(win, c.url ~= nil)
    win.b1:SetShown(c.primary ~= nil)
    win.b1:SetText(c.primary or "")
    win.b2:SetShown(c.secondary ~= nil)
    win.b2:SetText(c.secondary or "")
    L.buttons(win, c.secondary ~= nil)
end

for _, name in ipairs({
    "AlertPane", "QuitDialog", "UrlAlertPane", "ExchangeAlertPane", "ConnectionClosedDialog", "ReconnectDialog",
    "CopyWindow", "VersatileAlertPane", "DeleteReplyAlert", "MailDeleteReplyAlert", "ConfirmDeleteAlert",
    "ConfirmDeleteMailAlert", "TransferReplyAlert", "MailTransferReplyAlert", "TransferReplyPredefinedAlert",
}) do
    C.renderers[name] = Alert
end
C.renderers.Alert = Alert
