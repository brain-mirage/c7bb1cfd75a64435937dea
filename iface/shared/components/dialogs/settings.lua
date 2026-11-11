-- s6-rules-dialogs: the dialog windows have no settings of their own (their places and looks are the original's).
local C = TK.GetComponent("dialogs")
C.defaults = {}

function C:SettingsNodes() return {} end
