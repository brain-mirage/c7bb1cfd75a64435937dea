-- s6-dlss (round 1) and s6-reprojection-cloud-3 (run 78, register G-35). The owner, 2026-10-04: "add this as an
-- experimental joke subsection", "the controls would be on a subpage under experimental", "a joke feature, I mean
-- really add it in but we arnt serious about it". The Experimental tab's Neural Rendering (DLSS 5) section: a title
-- with two pages, About (what it is) and Controls (the switch, off by default, what this computer and this build
-- lack, and the model's controls as NVIDIA has announced them). Saved in the profile like every other setting; main.lua
-- hands the switch to the host (TK.Modular.Draw.NeuralRendering). It cannot run until NVIDIA releases DLSS 5's SDK:
-- so far DLSS 5 ships only in NBA 2K27 and NVIDIA's RTX Remix, made with their makers, on RTX 50 Series cards
-- (docs/user-related/decisions/2026-10-30-dlss5-joke-section.md). At the login screen and in the game.

local C = TK.GetComponent("neuralrendering")
local N = CS.TK.Modular.Draw.NeuralRendering
local SECTION = "Neural Rendering (DLSS 5)" -- the title both pages go under (core/global/settings.lua makes it)

C.defaults = { enabled = false, world_model = "1", character_model = "1", structure = 1, tone = 1,
               semantic_masks = true, keep_figures = true }

-- NVIDIA's three models (a game gives each to its scenes or its characters), named as RTX Remix 1.6 names them
local MODELS = { { value = "1", text = "Model A" }, { value = "2", text = "Model B" },
                 { value = "3", text = "Model C" } }

local function off() return C:DB().enabled ~= true end

-- Under the switch: on or off, and what this computer and this build lack, a line each (the host's list)
local function status()
    local state = C:DB().enabled == true and "On" or "Off"
    local unmet = N.UnmetText()
    if unmet == "" then return state .. "." end
    return state .. ". It cannot run here, so nothing changes. It needs:\n- " .. (unmet:gsub("\n", "\n- "))
end

function C:SettingsNodes()
    local function about(text) return { type = "description", width = "full", name = text } end
    local db, defaults = function() return self:DB() end, function() return self.defaults end
    return {
        { id = "neuralrendering", title = "About", parent = SECTION, order = self.order, category = "experimental",
          atLogin = true, db = db, defaults = defaults,
          tabs = { { name = "About", args = {
              { type = "description", name = "Experimental: what is on this tab may change or go." },
              about("A joke feature (the owner: \"we aren't serious about it\"). NVIDIA's DLSS 5 repaints each picture "
                  .. "with a generative model, for lifelike light and materials. Here it would repaint the world picture "
                  .. "only, never the interface, and nothing is sent: the server sees no difference."),
              about("It needs an NVIDIA GeForce RTX 50 Series card, Direct3D 12 (start the client with -force-d3d12) "
                  .. "and NVIDIA's DLSS 5 library. So far DLSS 5 ships only in NBA 2K27 and NVIDIA's RTX Remix, made "
                  .. "with their makers; NVIDIA has not released its SDK, so this client has no library to call. Until "
                  .. "it does, the switch on Controls does nothing."),
          } } } },
        { id = "neuralrenderingcontrols", title = "Controls", parent = SECTION, order = self.order + 0.1,
          category = "experimental", atLogin = true, db = db, defaults = defaults,
          tabs = { { name = "Controls", args = {
              { type = "toggle", key = "enabled", name = "Enable Neural Rendering (DLSS 5)" },
              about(status),

              { type = "header", name = "Models" },
              { type = "select", key = "world_model", name = "World Model", values = MODELS, disabled = off },
              { type = "select", key = "character_model", name = "Character Model", values = MODELS, disabled = off },
              about("NVIDIA's three models: one for the world, one for the characters and creatures."),

              { type = "header", name = "Intensity" },
              { type = "range", key = "structure", name = "Structure Intensity", min = 0, max = 2, step = 0.05,
                disabled = off },
              { type = "range", key = "tone", name = "Tone Intensity", min = 0, max = 2, step = 0.05, disabled = off },
              about("How far the model may change the shapes and fine detail, and the light and colour."),

              { type = "header", name = "Masks" },
              { type = "toggle", key = "semantic_masks", name = "Semantic Masks", disabled = off },
              { type = "toggle", key = "keep_figures", name = "Keep Figures and Items As Drawn", disabled = off },
              about("The model's own masks, and ours: characters, creatures and items on the ground keep their "
                  .. "pictures, so nothing a player must see is painted away."),
          } } } },
    }
end
