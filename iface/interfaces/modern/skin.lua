-- Modern's skin: the colours and panel finish Modern's panels and dialogs draw with (Skin.UI: TK.UI.With). s6-ui-core (the
-- five parts' step 2b): Modern's own table, which starts from the dialogs' default look (shared/components/dialogs/defaultskin.lua,
-- Shared / Reusable) and keeps its values until a restyle of Modern sets its own here (new values, never a change to the
-- default's tables in place). So a restyle moves Modern alone and leaves the look 7.x's and 5.x's dialogs fall back to,
-- and the tools, as they are (interface-separation.md, Q2 and Q5). s6-interface-5x round 15 (step 9): Modern's seam, kept.
local S = {}
for k, v in pairs(require("shared.components.dialogs.defaultskin")) do
    if k ~= "UI" then S[k] = v end
end

S.UI = TK.UI.With(S)

return S
