-- s6-crash-reports (plan P8): when the last session ended with an error or a crash, the login screen says so, with a
-- button that opens the report's folder (<user data>/crash-reports/<time>-<kind>/). The reports are our own, for the
-- owner's testing, and nothing is sent anywhere; C# writes them (TK.Unity.Crash.CrashReporter). The login screen calls
-- Show each time it shows.

local H = __tk
local W = TK.UI

local N = {}
TK.CrashNotice = N

local frame

-- s6-ui-core (round 134, 6i-4): fixed parts are the login shell's; the report-opening callback stays here.
local function part(name) return TK.Wrap(H:ShellToolPart("login", "crash." .. name)) end
local function build(parent)
    frame = TK.NameShellFrame(W.ShellPanel(TK.Wrap(H:ShellToolPart("login", "crash")), part("fill"), false,
        part("edge")), "TKCrashNotice")
    frame:SetParent(parent)
    frame:SetPoint("TOP", parent, "TOP", 0, -12)
    if parent == UIParent then W.HudPanel(frame) end
    frame.text = part("text")
    frame.open = TK.WrapShellButton(H:ShellToolPart("login", "crash.open"))
    frame.open:SetScript("OnClick", function() H:OpenLastSessionReport() end)
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
