-- s6-rules-dialogs: the web board (D-52) and the browser dialog (D-53). The original embeds a browser; plan 5.11 (D10)
-- shows the public pages in the system browser, and the authenticated board only once its cookie hand-over is proven,
-- so not yet. Their 73 request, the 62 page and the close are the model's.
--
-- s6-modular-g (interfaces): the windows' sizes and where their parts sit are the look's (C.look.WebBoard,
-- Browser, and their fill after each update); this file keeps what each dialog does.

local C = TK.GetComponent("dialogs")
local K = C.kit
local W = TK.UI
local H = __tk

--- The page's text and address, and a button that opens it in the system browser (a local action: nothing goes to the
--- server); its width L.openButton.
local function page(win, L)
    win.text = K.Block(win, 13)
    win.url = W.Label(win, "", 12, W.grey, "LEFT")
    win.open = W.Button(win, "Open in browser", L.openButton, L.buttonHeight, nil, function()
        if win.address then H:OpenUrl(win.address) end
    end)
end

local function show(win, text, address)
    win.text:SetText(text)
    win.address = address
    win.url:SetText(address or "")
    win.open:SetShown(address ~= nil)
end

-- D-52: Close (0; b too). Its page: a player's (public) or the board (its login).
-- Wire: WebBoardDialog::OnControlCommand 0x0046D360 (its pointer 0x0046D3B0 and keys 0x0046D4B0): Close (0); changing it
-- changes what the server sees.
local Board = { look = "WebBoard" }

function Board.build()
    local L = C.look.WebBoard
    local win = K.Window(L.width, L.height, "Web Board")
    page(win, L)
    win.close = K.Button(win, 0, "CLOSE", L.button)
    L.place(win)
    return win
end

function Board.update(win, view)
    local c = view.contents
    win.title:SetText(c.mode == 4 and (K.Text(c.name) ~= "" and (K.Text(c.name) .. "'s page") or "User Look") or "Web Board")
    if not c.url then
        show(win, "Waiting for the server...", nil)
    elseif c.board then
        show(win, "The board needs its sign-in, which this client does not pass on to the browser yet.", nil)
    else
        show(win, "This page opens in your web browser.", c.url)
    end
    -- s6-modular-g (interfaces, round 13): a look's own window for the mode (7.x's: 4a's size, frame and close by mode)
    if C.look.WebBoard.fill then C.look.WebBoard.fill(win, c) end
end

C.renderers.WebBoardDialog = Board

-- D-53: OK (0). The server's address (S 66 kind 0; F1's help page).
-- Wire: BrowserDialog::OnControlCommand 0x0046AD40 (its pointer 0x0046AD80): OK (0); changing it changes what the
-- server sees.
local Browser = { look = "Browser" }

function Browser.build()
    local L = C.look.Browser
    local win = K.Window(L.width, L.height, "Web Page")
    page(win, L)
    win.ok = K.Button(win, 0, "OK", L.button)
    L.place(win)
    return win
end

function Browser.update(win, view)
    local url = view.contents.argument
    show(win, "This page opens in your web browser.", type(url) == "string" and url or nil)
    -- s6-modular-g (interfaces, round 13): a look's own window (7.x's: 4a's frame and OK)
    if C.look.Browser.fill then C.look.Browser.fill(win, view.contents) end
end

C.renderers.BrowserDialog = Browser
