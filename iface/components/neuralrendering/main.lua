-- s6-dlss (round 1), s6-reprojection-cloud-3 (run 78, G-35): applies the profile's Neural Rendering (DLSS 5) switch to
-- the host (TK.Modular.Draw.NeuralRendering), on start, on each change and on a profile switch. The section's controls
-- stay in the profile until an integration reads them. Drawing only: nothing here reaches the wire.

local C = TK.GetComponent("neuralrendering")

function C:ApplySettings()
    CS.TK.Modular.Draw.NeuralRendering.Enabled = self:DB().enabled == true
end
