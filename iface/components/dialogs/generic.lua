-- s6-rules-dialogs: the window of a dialog without one of its own (the hired merchant, the clan bank, the power
-- dialog, the rankings, the web board, the plain dialogs...): its texts and one button per button control, by the
-- original's index. Its values are not kept (the model reads them as empty).
--
-- s6-modular-g (interfaces): the window's size and where its parts sit are the look's (C.look.Generic).
-- Wire: one button per button control of the dialog, carrying the index its class's OnControlCommand takes; changing
-- an index changes what the server sees.

local C = TK.GetComponent("dialogs")
local K = C.kit

local Generic = { look = "Generic" }

function Generic.build(view)
    local L = C.look.Generic
    local win = K.Window(L.width, L.height, "")
    win.text = K.Block(win, 13)
    win.buttons = {}
    for i = #view.controls, 1, -1 do
        local ctl = view.controls[i]
        if ctl.kind == "Button" then
            win.buttons[#win.buttons + 1] = K.Button(win, ctl.index, "#" .. ctl.index, L.button)
        end
    end
    L.place(win)
    return win
end

function Generic.update(win, view)
    win.title:SetText(view.name)
    local lines = {}
    for _, key in ipairs({ "title", "prompt", "text", "name", "argument", "owner" }) do
        local v = view.contents[key]
        if type(v) == "string" and v ~= "" then lines[#lines + 1] = K.Text(v) end
    end
    local id = view.contents.stringId
    if id then lines[#lines + 1] = K.String(id, "#" .. id) end
    win.text:SetText(table.concat(lines, "\n"))
    C.look.Generic.fit(win)
end

C.renderers.Generic = Generic
