-- s6-input (round 50, separation step 4b; docs/development/interface-separation.md 4.3 and 5.12): Modern's look of the
-- shared world view (components/worldview), which the view drew itself in every interface before: a grey edge round the
-- frame, over its outermost pixels, and a label at its top left that the view fills with the map's title (and its
-- settings while the frames are unlocked). The view builds it the first time Modern is the active interface (Modern's
-- manifest, worldViewLook), at its start or at a switch to Modern, and shows it only while Modern is (round 52). Drawing
-- only.
-- s6-ui-core (round 85): the XML twin's; the edge and the label are worldview.xml's (core/xml.md).

local E = require("interfaces.modern.elements")

--- Builds the look on f, the view's frame; returns its label and everything it drew (the view hides them while another
--- interface is active).
return function(f)
    local ui = TK.Xml.Load("worldview.xml", { parent = f, elements = E })
    return ui.label, { ui.edge, ui.label }
end
