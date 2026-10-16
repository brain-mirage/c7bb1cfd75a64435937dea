local C = TK.GetComponent("mailparcels")

-- Off by default (the owner, 2026-10-02): the minimap's mail and parcel icons stand for these buttons.
C.defaults = TK.Visibility.Defaults({ enabled = false })

-- Where the original's buttons were drawn before they were a panel: 8 to the left of the micro menu with its bag button
-- (318 wide at -20, 18). s6-ui-settings: that button is off by default since 2026-10-03 (the owner), leaving a 40 gap;
-- the place stays, so a profile that keeps the button is not overlapped.
C.defaultPosition = { "BOTTOMRIGHT", "BOTTOMRIGHT", -346, 18 }

C:StandardSettings("mailparcels", {})
