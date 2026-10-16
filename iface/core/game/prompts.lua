-- s6-interface-5x (round 12, separation step 3 and gap G3; docs/development/interface-separation.md, sections 5.7 and
-- 15.3): where the rules' prompts are drawn. The original draws every LineInputPane on its chat bar (LineInputPane.cpp:46),
-- the one-key prompts too (CharInputPane is one); an interface's chat that draws the rules' line draws the prompts there
-- and says so here: a Text prompt's line (Modern's chat frame, 5.x's chat) or every prompt (7.x's chat bar). Classic
-- Commands' prompt display (components/classic) draws a prompt only while no chat that draws its kind shows. It replaces
-- Classic's reads of Modern's chat frame and 5.x's chat (W2: in 7.x a Text prompt was drawn twice). Drawing only: nothing
-- is sent, and the rules' handling of the prompts' keys is unchanged.

TK.Game = TK.Game or {}
local P = { hosts = {} }
TK.Game.Prompts = P

--- An interface's chat that draws the rules' prompts while isShown() is true, under its panel (latest first): a Text
--- prompt's line, or every prompt's with everyKind.
function P.ProvideHost(panelId, isShown, everyKind)
    table.insert(P.hosts, 1, TK.Mark({ panel = panelId, shown = isShown, every = everyKind == true }))
end

-- s6-interface-5x (round 13, the separation's step 11): a chat panel turned off draws no prompt any more
TK.OnWithdraw(function(name, panel) TK.DropOwned(P.hosts, name, panel) end)

--- Whether a chat that draws a prompt of this kind (the rules' PromptKind: "Text", "Char", ...) shows now.
function P.Drawn(kind)
    for _, h in ipairs(P.hosts) do
        if (h.every or kind == "Text") and h.shown() then return true end
    end
    return false
end

return P
