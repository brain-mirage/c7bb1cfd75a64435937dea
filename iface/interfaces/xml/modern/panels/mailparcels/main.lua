-- The original's parcel and letter buttons as a panel of their own (s6-rules-dialogs round 27, the owner). The buttons
-- are the dialogs' ParcelPane window (dialogs/panes.lua, D-76), drawn in this panel: the panel decides whether they
-- show, where, and their alpha and scale. Hidden, the dialog model's pane is the same: it takes the counts, and the
-- minimap's mail and parcel icons are its controls, so nothing on the wire changes. Off, this code is not loaded at all
-- (step 11; s6-characters round 49: no longer kept loaded): the pane, its counts and its presses are the dialogs' alone.
-- s6-ui-core (round 85): the XML twin's scripts; the panel's frame is main.xml's (core/xml.md).

local C = TK.GetComponent("mailparcels")

-- s6-characters (rounds 46 and 47, step 6 of the interface separation): the dialogs' parcel window is drawn in this
-- panel by taking its parent in (TK.Dialogs.ParcelParent) while the panel's frame is shown. Hidden (its switch off, out
-- of the world, its visibility rules, or step 11's unload, which hides a panel's frames before it destroys them with
-- everything below), the frame gives the parent back to UIParent, hidden, so the window and its controls stay the
-- dialogs'. Drawing only: the pane and its presses are the dialogs' (the minimap's icons press it while this is off).
local function hold(f, on)
    local held = TK.Dialogs.ParcelParent()
    held:ClearAllPoints()
    if on then
        held:SetParent(f)
        held:SetAllPoints(f)
        held:Show()
    else
        held:SetParent(UIParent)
        held:Hide()
    end
end

-- the scripts main.xml names
local scripts = {}

function scripts.Hold(f) hold(f, true) end

function scripts.Release(f) hold(f, false) end

function C:OnEnable()
    local f = TK.Xml.Load("main.xml", { scripts = scripts }).frame
    self.frame = f
    TK.Visibility:Attach(f, function() return self:DB() end)
    TK.EditMode:Register(f, "mailparcels", "Mail and Parcels", C.defaultPosition, "mailparcels")
end

function C:ApplySettings()
    TK.Visibility:Apply(self.frame)
end
