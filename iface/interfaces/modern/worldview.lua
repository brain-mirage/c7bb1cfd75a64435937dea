-- s6-input (round 50, separation step 4b; docs/development/interface-separation.md 4.3 and 5.12): Modern's look of the
-- shared world view (components/worldview), which the view drew itself in every interface before: a grey edge round the
-- frame, over its outermost pixels, and a label at its top left that the view fills with the map's title (and its
-- settings while the frames are unlocked). The view builds it the first time Modern is the active interface (Modern's
-- manifest, worldViewLook), at its start or at a switch to Modern, and shows it only while Modern is (round 52). Drawing
-- only.

local W = require("interfaces.modern.skin").UI

--- Builds the look on f, the view's frame; returns its label and everything it drew (the view hides them while another
--- interface is active).
return function(f)
    local edge = f:CreateTexture(nil, "OVERLAY")
    edge:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2)
    edge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
    edge:SetTexture("tk:border")
    edge:SetVertexColor(0.45, 0.45, 0.48, 1)
    local label = W.Label(f, "", 11, { 0.85, 0.85, 0.85 })
    label:SetFont(11, "OUTLINE")
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -5)
    label:SetJustifyH("LEFT")
    return label, { edge, label }
end
