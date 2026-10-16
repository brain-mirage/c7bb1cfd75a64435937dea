-- s6-crash-reports (plan P8): when the last session ended with an error or a crash, the login screen says so, with a
-- button that opens the report's folder (<user data>/crash-reports/<time>-<kind>/). The reports are our own, for the
-- owner's testing, and nothing is sent anywhere; C# writes them (TK.Unity.Crash.CrashReporter). The login screen calls
-- Show each time it shows.

local H = __tk
local W = TK.UI

local N = {}
TK.CrashNotice = N

local frame

local function build(parent)
    frame = W.Panel(parent, "TKCrashNotice")
    frame:SetSize(520, 44)
    frame:SetPoint("TOP", parent, "TOP", 0, -12)
    frame.text = W.Label(frame, "The last session ended with an error.", 14, { 1, 0.45, 0.35 }, "LEFT")
    frame.text:SetPoint("LEFT", frame, "LEFT", 14, 0)
    frame.open = W.Button(frame, "Open the report", 150, 28, nil, function() H:OpenLastSessionReport() end)
    frame.open:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
end

--- Shows the notice at the top of the login screen if the last session left a report.
function N:Show(parent)
    if H:GetLastSessionReport() == "" then
        if frame then frame:Hide() end
        return
    end
    if not frame then build(parent) end
    frame:Show()
end

return N
