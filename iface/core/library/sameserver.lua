-- s6-library round 22 (the owner: when the client connects through an address the Library does not know, notice that it
-- may be a server it already has, and ask the player whether to treat it as that server or keep it separate; never merge
-- silently). The C# side gives the question once per session and address (__tk:LibrarySameServerQuestion): the server
-- sent the same table list as a saved server's, or the character logged into is one that server's Library knows. It is
-- asked with the shared Yes/No dialog, after any other question already showing. Yes: the address becomes that server's
-- "Also known as", from the next login; No: kept apart. Either way it is not asked there again. Round 24 (QA's head
-- note): it comes before the prebuilt Library's offer, which waits for the table list (prebuild.lua), is taken by the
-- question while it waits or shows, and is made after a No; after a Yes the offer for a "new" server does not apply.
-- Nothing is sent for any of it.

local W = TK.UI
local H = __tk

local S = {}
TK.LibrarySameServer = S

local QUESTION_HEIGHT = 40 -- two lines of the dialog's text (prebuild.lua's)
local ASK_EVERY = 0.5      -- seconds between asks of the C# side

--- The question's text: what matched, and what Yes does. A server name too long for two lines is "a saved server".
function S.Text(q, name)
    name = name or q.name
    local seen = q.reason == "character" and (q.character .. " is your character on " .. name .. ".")
        or ("This looks like " .. name .. ".")
    return seen .. "\nUse its Library from your next login?"
end

-- The question showing (its table, and the dialog's Yes it set), until it is answered, replaced or taken down.
local shown

--- Asks it. The answer carries the question's session: the C# side ignores one given after that session ended. offer:
--- the prebuilt Library's offer it took (TK.LibraryPrebuild:Withdraw), made after a No while the session runs (Astra's
--- pass 4: a No after a switch leaves it for the address's next connection).
function S:Ask(q, offer)
    local function answer(same) H:LibrarySameServerAnswer(q.session, q.server, q.candidate, q.address, same) end
    local yes = function() answer(true) end
    W.Confirm(S.Text(q), yes, function()
        answer(false)
        if offer and H:LibrarySession() == q.session then TK.LibraryPrebuild:Offer(offer.host, offer.port, offer.name) end
    end)
    if W.confirm.text:GetStringHeight() > QUESTION_HEIGHT then W.confirm.text:SetText(S.Text(q, "a saved server")) end
    shown = { q = q, yes = yes }
end

--- Asks the C# side for the session's question and asks it if there is one, taking the prebuilt Library's offer for its
--- address (round 24). The watch below calls it, and the offer once it has waited for the table list (prebuild.lua).
function S:Poll()
    local q = H:LibrarySameServerQuestion()
    if not q then return end
    local prebuild = TK.LibraryPrebuild
    S:Ask(q, prebuild and prebuild:Withdraw(q.address))
end

-- The C# side is asked only while no other question shows but the prebuilt Library's offer (round 24), and its question
-- is shown at once: none is held back, so a question is always the connection's of the moment (Astra's review: a held
-- one could outlive a switch of server). Round 23 (the head's review of round 22): a question showing when its session
-- changes (another server, or none) is taken down unanswered, so it never stands over another server's session.
-- Every ASK_EVERY seconds, the first ASK_EVERY after the start (s6-ui-core round 101, T11 step 2: the host keeps the
-- countdown, TK.Util.Throttled).
local watch = CreateFrame("Frame", nil, UIParent)
watch:SetScript("OnUpdate", TK.Util.Throttled(ASK_EVERY, function()
    local c = W.confirm
    if shown and not (c and c:IsShown() and c.onYes == shown.yes) then shown = nil end -- answered, or another question
    if shown and H:LibrarySession() ~= shown.q.session then
        shown = nil
        c:Hide()
    end
    local prebuild = TK.LibraryPrebuild
    if c and c:IsShown() and not (prebuild and prebuild:Showing()) then return end
    S:Poll()
end, ASK_EVERY))

return S
