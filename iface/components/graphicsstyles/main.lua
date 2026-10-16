-- s6-modular: applies the profile's drawing styles (settings.lua) to the drawing host, on start, on each change and on
-- a profile switch.

local C = TK.GetComponent("graphicsstyles")
local G = CS.TK.Modular.Draw.GraphicsStyles

-- s6-ui-core (build 41; the owner, 2026-10-05: "Cycling through themes should set whatever you set under that theme"): the
-- Cycle Graphics Style key steps through modes, with a short notice. The owner's hotfix (2026-10-06): "it should default
-- to modern graphics but it should go Retro> modern> 3d normal > 3d hd Retro", "3d normal with modern fall back and then
-- 3d high qual with modern fallback". So the modes are the default style (Modern), Custom 3D at Normal ("3D"), Custom 3D at HD
-- (every category, falling back to Modern: what has no 3D model draws in Modern), then the other drawing styles whose
-- module declares a mode (its module.json's "cycle": Retro; GraphicsStyles.CycleStyles), and round to Modern. A style
-- draws every category it serves, the rest in the default style. It is an override for now, never saved: the game starts
-- on the page's choices (Modern unless the player chose otherwise, the client's defaults), at Modern's place in the
-- cycle, and a choice on this page goes back to them. Each mode keeps what the player set for it: the Wind Armor Fix in
-- all of them, a style's own options in its mode, where the options its manifest names (Retro's whole figures) stand in
-- for the ones the player left at their default. Drawing only: nothing is sent. (After build 41, s6-optimize's audit:
-- the modes come from the modules' manifests, and no module's id is written here.)
C.modes = { C.styles[1] }
C.modes[2] = { id = "custom-3d", name = "3D", options = {}, custom = { kind = "3d", quality = "normal" } }
C.modes[3] = { id = "custom-3d-hd", name = "3D HD", options = {}, custom = { kind = "3d", quality = "hd" } }
for i = 2, #C.styles do C.modes[#C.modes + 1] = C.styles[i] end -- s6-ui-core (round 54): settings.lua's styles
C.cycle = 1     -- the mode now: its place in C.modes (1, Modern)
C.user = true   -- the page's choices are drawn, not the mode (at the start, and after a choice on the page)

--- s6-ui-core (round 63; Quick Settings): the drawing choice a category uses, including the cycle's temporary override.
--- Keeping this with the styles leaves settings callers independent of the component's private cycle state.
--- Returns the style choice and the Custom kind (2d or 3d).
function C:DrawingChoice(category)
    local db = self:DB()
    if self.user then return db[category] or self.defaults[category], db["custom:" .. category .. ":kind"] or "2d" end
    local mode = self.modes[self.cycle]
    if mode.custom then return "custom", mode.custom.kind end
    return G.Serves(mode.id, category) and mode.id or self.defaults[category], "2d"
end

--- s6-ui-core (round 54): a category saved as a module that is not a style (3D map objects', from s6-reprojection's round
--- 29 and its carry-over of the old 3D Map Objects toggle) is Custom 3D, over the style that module drew over.
function C:CarryOver(db)
    for _, c in ipairs(self.categories) do
        local id = db[c.key]
        if id and id ~= "custom" and not self.isStyle[id] then
            for _, o in ipairs(self.options) do
                if o.module == id and o.over then
                    db[c.key] = "custom"
                    db["custom:" .. c.key .. ":kind"] = "3d"
                    db["custom:" .. c.key .. ":fallback"] = db[o.db] or o.default
                    TK.DB:MarkDirty()
                    break
                end
            end
        end
    end
end

function C:ApplySettings()
    local db = self:DB()
    self:CarryOver(db) -- s6-ui-core (round 54)
    local style = not self.user and self.modes[self.cycle] or nil -- s6-ui-core (build 41): the cycle's mode, nil for the page's
    for _, c in ipairs(self.categories) do
        local id = db[c.key] or self.defaults[c.key]
        -- a style's mode draws 2D in its own style, never the page's Custom (s6-reprojection's rule)
        if style and not style.custom then id = G.Serves(style.id, c.key) and style.id or self.defaults[c.key] end
        if style and style.custom then
            -- the hotfix's 3D modes: Custom 3D for every category, at the mode's quality, falling back to Modern
            G.SelectCustom(c.key, style.custom.kind, style.custom.quality, self.defaults[c.key])
        elseif id == "custom" then
            -- s6-reprojection (round 30; the owner's Custom assets): Custom, with its kind (2D or 3D), quality (Normal or
            -- HD) and fallback (Modern or Retro), the keys of docs/development/jobs/s6-reprojection/FOR-s6-ui-core-r30.md
            local k = "custom:" .. c.key .. ":"
            G.SelectCustom(c.key, db[k .. "kind"] or "2d", db[k .. "quality"] or "normal", db[k .. "fallback"] or self.defaults[c.key])
        else
            G.Select(c.key, id)
        end
    end
    -- the modules' options from the profile (s6-modular-c: a module nothing selects only stores them, so each profile's
    -- follow it). Custom's Fallback is the host's own (DrawHost.Fallback), so it leaves these as saved.
    for _, o in ipairs(self.options) do
        local value = db[o.db] or o.default
        -- s6-ui-core (build 41): in a style's mode, the option its manifest names where the player left the default
        if style and o.module == style.id and style.options[o.key] and value == o.default then value = style.options[o.key] end
        G.SetOption(o.module, o.key, value)
    end
    -- s6-characters (round 41): the 7.5.2 Wind armor's 5.x shimmer (settings.lua), on unless the profile says false
    G.SetPaletteOverride("windArmorShimmer", db.windArmorShimmer ~= false)
    -- s6-modular-d (Retro rule 16): the Tiles' style may ask for its own world view (C:Presentation in worldview)
    local view = TK.GetComponent("worldview")
    if view and view.frame then view:ApplySettings() end
end

--- s6-ui-core (build 41): a change on this page goes back to User; one made elsewhere (the Misc page's Wind Armor Fix)
--- keeps the cycle's mode.
function C:OnSettingChanged(node)
    if node and node.id == self.name then self.cycle, self.user = 1, true end
    self:ApplySettings()
end

--- s6-ui-core (build 41): the Cycle Graphics Style key's press: the next mode, drawn at once, and its notice.
function C:CycleStyle()
    self.cycle, self.user = self.cycle % #self.modes + 1, false
    self:ApplySettings()
    TK.Notify("Mode: " .. self.modes[self.cycle].name, "graphicsstylecycle") -- the newest mode alone, on top
end

-- Unbound by default (no key is free for it among the original's).
TK.Bindings:RegisterCommand("GRAPHICSSTYLECYCLE", "Cycle Graphics Style", function() C:CycleStyle() end)
