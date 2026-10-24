local C = TK.GetComponent("worldview")

C.defaults = TK.Visibility.Defaults({
    -- s6-world-view (round 29): the owner's names: the live area is the original's 17 x 15 (19 x 17 with Expand Live
    -- View), the outer area what is drawn beyond it.
    cols = 17,
    rows = 15,
    autoExtend = true, -- the owner, 2026-10-02: the outer area on by default, filling the window
    expandLive = false,
    outerDim = 0.20,
    outerSaturation = 0.5,
    -- s6-world-view (round 36): the owner's "Add Border to Zone" (2026-10-04), off, light grey; round 37 (the owner,
    -- 2026-10-04: "like 50% see though as it stands out too much"): half see-through
    zoneBorder = false,
    zoneBorderRed = 211,
    zoneBorderGreen = 211,
    zoneBorderBlue = 211,
    zoneBorderOpacity = 50,
    worldScale = "auto",
    includeOuter = false,
    smoothing = "none",
    -- s6-upscale (the owner, 2026-10-08): Upscaling off; Blending on for xBR; Blend Palette Animation on by default
    upscaleMethod = "none",
    upscaleScale = 2,
    upscaleBlend = true,
    upscaleBlendPalette = true,
    width = 0,
    height = 0,
    originalColour16 = true,
    -- s6-characters (round 45): the owner's Smooth Movement (the Motion page, below); s6-world-view (round 39; the owner,
    -- 2026-10-06: "Id like the default config to have smooth character animation off but that 2d fix defaults to on"): off
    smoothMovement = false,
    fix2dFlicker = true, -- s6-world-view (round 39): its Fix 2D Flicker (below)
    shadows = __tk:ClientSettingBool("options", "shadow"), -- s6-ui-settings: the original's Shadow, as map_effect below
    seeThrough = true,
    fadeOver = false, -- s6-effects-c (round 8): See-Through's child, off by default
    objectTransparency = false,
    -- s6-world-view (O-03): the original's "Map" effects option, from its settings (settings.toml [options] map_effect)
    mapEffects = __tk:ClientSettingBool("options", "map_effect"),
    -- s6-world-view: the outer area's extras (plan 5.10), off by default
    farViewObjects = false,
    farViewRememberItems = false,
    rememberConfirmMs = 2000,
    rememberMaxAgeMinutes = 10,
})

C.defaultPosition = { "CENTER", "CENTER", 0, 40 }

-- s6-ui-core (round 54; the owner's rule for every settings page, 2026-10-05): what a setting needs to have an effect,
-- shown by its (!) while it is on (core/settings.lua, TK.Needs); it stays usable and keeps its value (these were the
-- page's disabled conditions, s6-world-view's).
local remembering = TK.Needs("Remember Items", function(db) return db.farViewRememberItems end) -- s6-world-view
local notExtending = TK.Needs("Auto Extend Outer Area off", function(db) return not db.autoExtend end) -- round 29
local zoneBorder = TK.Needs("Add Border to Zone", function(db) return db.zoneBorder end) -- round 36: its colour
local seeThrough = TK.Needs("See-Through", function(db) return db.seeThrough ~= false end) -- s6-effects-c (round 8)
-- s6-world-view (round 29): Include Outer Area decides for Auto and Stretch, and has nothing to decide with Auto Extend;
-- the smoothing applies where the picture can be enlarged.
local fitting = TK.Needs("Scale: Auto or Stretch", function(db) return db.worldScale == "auto" or db.worldScale == "stretch" end)
local enlarging = TK.Needs("Scale: Fixed 2x or more, or Stretch",
    function(db) return not (db.worldScale == "auto" or db.worldScale == "0.5" or db.worldScale == "1") end)
-- s6-upscale (the owner, 2026-10-08): the scales each Upscaling method supports (UpscaleChoice.Scales); a scale kept from
-- another method shows and applies as the method's first (UpscaleChoice.Normalised). Blending is xBR's only, and Blend
-- Palette Animation needs it applied.
local UPSCALES = { mmpx = { 2, 4 }, scalefx = { 3 }, xbr = { 2, 3, 4 }, epx = { 2, 3 } }
local function upscaleScales(db)
    local values = {}
    for _, s in ipairs(UPSCALES[db.upscaleMethod] or UPSCALES.xbr) do values[#values + 1] = { value = s, text = s .. "x" } end
    return values
end
function C.UpscaleScale(db)
    local scales = UPSCALES[db.upscaleMethod] or UPSCALES.xbr
    for _, s in ipairs(scales) do if s == db.upscaleScale then return s end end
    return scales[1]
end
local upscaling = TK.Needs("Upscaling: a method", function(db) return (db.upscaleMethod or "none") ~= "none" end)
local blendForm = TK.Needs("Upscaling: xBR", function(db) return db.upscaleMethod == "xbr" end)
local blending = TK.NeedSetting("upscaleBlend")

-- s6-ui-core (round 83; the owner, 2026-10-09: "the graphic options in it basically only apply to the game world and we
-- usually have that in the settings not in the interface"; research 2026-10-09-interface-graphics-options.md): the
-- component's settings on two pages, the same keys, defaults and setters (C:SettingsNodes, below). The pane's page
-- (C.tabs) keeps the frame's own: its switch, alpha, size, visibility and place. How the game world is drawn is
-- Settings > General > Graphics > World View (C.graphicsTabs).
C.tabs = {
    { name = "General Settings", args = {
        { type = "toggle", key = "enabled", name = "Enabled" },
        { type = "range", key = "alpha", name = "Alpha", min = 0.1, max = 1, step = 0.05 },
        { type = "description", name = "How the game world is drawn (its scale, the outer area, the original's graphics options) is on the General tab: Graphics, World View." },
        { type = "header", name = "Frame Size" },
        { type = "description", name = "0 sizes the frame by itself: to the picture, or with Auto Extend to the whole window. A size gives the world view that space: a smaller frame shows the middle of the world, and Auto, Stretch and Auto Extend fit into it." },
        { type = "range", key = "width", name = "Width", min = 0, max = 4000, step = 8 },
        { type = "range", key = "height", name = "Height", min = 0, max = 3000, step = 8 },
    } },
    { name = "Visibility", args = TK.StandardVisibilityArgs },
    -- s6-modular-g (interfaces, phase 1): Layout took the Alignment tab's place; no Scale (the world's scaling is
    -- the graphics page's, below)
    { name = "Layout", args = TK.LayoutArgs(function() return "worldview" end, { noScale = true }) },
}

C.graphicsTabs = {
    { name = "World View", args = {
        -- s6-ui-core (build 41): Original 16-bit Colour is on the Experimental tab's Misc page now (below)
        { type = "header", name = "The Original's Graphics Options" },
        { type = "toggle", key = "shadows", name = "Shadows" },
        { type = "toggle", key = "seeThrough", name = "See-Through" },
        { type = "toggle", key = "fadeOver", name = "Fade Over the Player", requires = { seeThrough } }, -- s6-effects-c (round 8)
        { type = "toggle", key = "objectTransparency", name = "Object Transparency" },
        { type = "toggle", key = "mapEffects", name = "Map Effects" }, -- s6-world-view (O-03)
        { type = "description", name = "As the original's options tab: shadows draw the night as a mask with lights (off: darker colours instead); see-through lets the player be seen behind the objects around them; object transparency draws every object a little see-through, near the player or not; map effects are the full-screen effects some maps have (a red wave, water light)." },
        { type = "description", name = "Fade Over the Player (not the original's; under See-Through): roofs, trees and walls drawn over your character are left out round them, their edge dithered, and the whole wall hiding them turns half see-through, as in the 3D view. A click still picks what it picked." }, -- s6-effects-c (round 8); s6-effects (round 13): the whole wall
        -- s6-world-view (round 29): the outer area, what the world view draws beyond the live area
        { type = "header", name = "Outer Area" },
        { type = "toggle", key = "autoExtend", name = "Auto Extend Outer Area" },
        { type = "description", name = "The outer area fills the world view's space at the current scale (a window 50 cells wide shows 50), and the Columns and Rows below are not used." },
        { type = "range", key = "cols", name = "Columns (tiles)", min = 17, max = 101, step = 2, requires = { notExtending } },
        { type = "range", key = "rows", name = "Rows (tiles)", min = 15, max = 101, step = 2, requires = { notExtending } },
        { type = "toggle", key = "expandLive", name = "Expand Live View" },
        { type = "description", name = "Off, the live area is the original's 17 x 15 and the outer area starts after it, as in the official client. On, the live area is 19 x 17: the one-cell band round it, whose objects the server already sends, is drawn as live. It changes only what is drawn: clicks and targeting stay the original's." },
        { type = "range", key = "outerDim", name = "Outer Area Darkness", min = 0, max = 1, step = 0.05 },
        { type = "range", key = "outerSaturation", name = "Outer Area Saturation", min = 0, max = 1, step = 0.05 },
        { type = "description", name = "The live area is always drawn as it is. The outer area is darker by the darkness, and keeps the saturation's part of its colours (1 its own colours, 0 grey). What stands in the live area is drawn whole over it, and what stands beyond the live area takes the outer area's look." },
        -- s6-world-view (round 36): the owner's "Add Border to Zone" (2026-10-04), its colour nested under it
        { type = "toggle", key = "zoneBorder", name = "Add Border to Zone" },
        { type = "break" },
        { type = "range", key = "zoneBorderRed", name = "Border Colour: Red", min = 0, max = 255, step = 1, requires = { zoneBorder } },
        { type = "range", key = "zoneBorderGreen", name = "Border Colour: Green", min = 0, max = 255, step = 1, requires = { zoneBorder } },
        { type = "range", key = "zoneBorderBlue", name = "Border Colour: Blue", min = 0, max = 255, step = 1, requires = { zoneBorder } },
        { type = "range", key = "zoneBorderOpacity", name = "Border Opacity (%)", min = 0, max = 100, step = 5, requires = { zoneBorder } }, -- round 37
        { type = "description", name = "A line one pixel wide all the way round the live area's edge, on its outermost pixels where the outer area begins, at any scale and window size, in the colour of the three sliders (light grey at first) and as opaque as the Opacity slider makes it (half see-through at first). It follows the map's edges where the live area runs past them. Drawing only: clicks are as without it. The 3D view draws it on the ground, one of its picture's pixels wide." },
        { type = "toggle", key = "farViewObjects", name = "Objects Beyond Range" },
        { type = "description", name = "Draws in the outer area the monsters, people and items the server happens to send beyond the original's range ([View] FarViewObjects). They may be missing or out of date, and can never be clicked or targeted." },
        { type = "toggle", key = "farViewRememberItems", name = "Remember Items (test mode)" },
        { type = "description", name = "Ground items you have seen stay drawn, faded and outlined, in the outer area after you walk away ([View] FarViewRememberItems). Purely visual: what you send is the same with it on or off." },
        { type = "range", key = "rememberConfirmMs", name = "Unconfirmed After (ms)", min = 500, max = 10000, step = 250, requires = { remembering } },
        { type = "range", key = "rememberMaxAgeMinutes", name = "Forget After (minutes)", min = 1, max = 60, step = 1, requires = { remembering } },
        -- s6-world-view (round 29): the scale, what must fit, and the smoothing
        { type = "header", name = "Scaling" },
        { type = "select", key = "worldScale", name = "Scale",
          values = { { value = "auto", text = "Auto" }, { value = "0.5", text = "Fixed 0.5x" }, { value = "1", text = "Fixed 1x" },
                     { value = "2", text = "Fixed 2x" }, { value = "3", text = "Fixed 3x" }, { value = "4", text = "Fixed 4x" },
                     { value = "stretch", text = "Stretch" } } },
        { type = "description", name = "Auto draws the original's pixels at their own size while what must fit fits, and shrinks the picture when the space is smaller; it never enlarges. Fixed keeps one size, and a smaller space shows the middle (0.5x halves: each 2 x 2 pixels become one). Stretch fills the space, larger or smaller, keeping the proportions." },
        { type = "toggle", key = "includeOuter", name = "Include Outer Area", requires = { notExtending, fitting } },
        { type = "description", name = "For Auto and Stretch: off, only the live area must fit, so a smaller window first shows less of the outer area; on, the live area and the outer area must fit together." },
        { type = "select", key = "smoothing", name = "Smoothing", requires = { enlarging },
          values = { { value = "none", text = "None" }, { value = "smooth", text = "Smooth (sharp bilinear)" },
                     { value = "xbr", text = "xBR smoothing" } } },
        { type = "description", name = "Where the picture is enlarged: None keeps the pixels sharp; Smooth is sharp bilinear; xBR is an edge-directed pixel-art scaler (the MIT relative of xBRZ) that draws diagonals and curves smooth. Shrunk, the picture is always averaged. The UI and its text are not smoothed." },
    } },
}

-- s6-upscale (the owner, 2026-10-08): the art itself upscaled once by a pixel-art scaler (TK.WorldView.ArtUpscaling).
-- s6-reprojection-cloud-1 (run 20; head note 69, the owner, 2026-10-23: "upscaling to 2x 4x etc should be an option in
-- experimental and upscaling should be off"): moved from the World View graphics page to its own page on the Experimental
-- tab, the same keys, off (None) by default; a profile saved with it on takes None once (main.lua's UpscalingMoved). Off,
-- nothing of it runs: no picture is made, no twin painted, nothing kept (ArtUpscaling.Set lets everything go).
C.upscalingTabs = {
    { name = "Upscaling", args = {
        { type = "description", name = "Experimental: what is on this tab may change or go." },
        { type = "select", key = "upscaleMethod", name = "Upscaling",
          values = { { value = "none", text = "None" }, { value = "mmpx", text = "MMPX" }, { value = "scalefx", text = "ScaleFX" },
                     { value = "xbr", text = "xBR" }, { value = "epx", text = "Scale2x/EPX" } } },
        { type = "select", key = "upscaleScale", name = "Upscaling Scale", requires = { upscaling },
          values = function() return upscaleScales(C:DB()) end, get = function() return C.UpscaleScale(C:DB()) end },
        { type = "toggle", key = "upscaleBlend", name = "Blending", requires = { blendForm } },
        { type = "toggle", key = "upscaleBlendPalette", name = "Blend Palette Animation", indent = 1, requires = { blending } },
        { type = "description", name = "Upscaling redraws the game's art itself at 2x to 4x as it loads, rounding its edges, in 2D and 3D. MMPX, ScaleFX and Scale2x/EPX keep the art's own colours; xBR can also blend them (Blending). Blend Palette Animation blends animated colours (water, candles) too, one picture per step; off, those are upscaled without blending. None draws the original art." },
    } },
}

--- The component's pages (s6-ui-core round 83): the pane's on the Interface tab ("worldview", the shared panel's page:
--- interfaces/modern/interface.lua), and the game world's graphics under General's Graphics title ("worldviewgraphics",
--- core/settings.lua's GENERAL_ORDER), both on the component's settings, so saved profiles, resets and the interfaces'
--- first values stay as they were. Run 20 (head note 69): and the Upscaling rows on the Experimental tab
--- ("worldviewupscaling"), on the same settings.
function C:SettingsNodes()
    local db, defaults = function() return self:DB() end, function() return self.defaults end
    return {
        { id = "worldview", title = self.title, order = self.order, tabs = self.tabs, db = db, defaults = defaults },
        { id = "worldviewgraphics", title = "World View", parent = "Graphics", category = "general", order = self.order,
          tabs = self.graphicsTabs, db = db, defaults = defaults },
        -- after the World Renderer's and Skybox's pages (913, 913.5: components/worldrenderer), with the world's drawing
        { id = "worldviewupscaling", title = "Upscaling", category = "experimental", order = 913.7,
          tabs = self.upscalingTabs, db = db, defaults = defaults },
    }
end

-- s6-ui-core (round 54; the owner, 2026-10-05: "I don't think the retro world view dropdown here makes sense anymore? We
-- have places to change this in multiple areas?"): Retro World View (the Retro module's old-version view, its option's
-- manifest "page"), moved from Asset Styles to this page, after the Smoothing: the old view's size and 0.79 shrink are set
-- nowhere else. Its key stays Asset Styles' (saved profiles keep it); added once every component is loaded. Round 83: on
-- the graphics page, with the Scaling it sizes.
TK.On("PLAYER_LOGIN", function()
    local styles, args = TK.GetComponent("graphicsstyles"), C.graphicsTabs[1].args
    if not styles or not styles.OptionsFor or args.moduleOptions then return end
    args.moduleOptions = true
    for i, a in ipairs(args) do
        if a.key == "smoothing" then -- after the Smoothing and its description (run 20: the Upscaling rows went to Experimental)
            for j, o in ipairs(styles:OptionsFor("worldview")) do table.insert(args, i + 1 + j, o) end
            break
        end
    end
end)

-- s6-ui-core (build 41; the owner, 2026-10-05: they could not find it on this page): Original 16-bit Colour on the
-- Experimental tab's Misc page (core/settings.lua, TK.MiscNode), the same key and behaviour.
local misc = TK.MiscNode.tabs[1].args
misc[#misc + 1] = { type = "toggle", name = "Original 16-bit Colour", default = true,
    desc = "The map in the original's 16-bit colours. Off: the full 8-bit palette colours.", -- a tooltip (short text on the page)
    get = function() return C:DB().originalColour16 ~= false end,
    set = function(node, v)
        C:DB().originalColour16 = v and true or false
        C:Changed(node, "originalColour16", v)
    end }

-- s6-characters (round 45; the owner, open question 57: "Add that as an experimental option Smooth Walking (what about when
-- riding a horse?) Maybe Smooth Movement? [x]"): on by default; off draws the original's jumping step. Drawing only
-- (TK.WorldView.SmoothMovement): the steps, what is sent and when, and what a click picks stay the original's.
-- s6-ui-core (round 60; the owner, 2026-10-06: "Move the smooth character movement setting from experimental misc here.
-- Make sure its called Smooth Character Movement"): on Graphics > Advanced > Motion (components/interpolation/settings.lua
-- lists this row), the same key and behaviour. s6-world-view (round 39; the owner, 2026-10-06): off by default.
C.smoothMovementOption = { type = "toggle", name = "Smooth Character Movement", default = false,
    desc = "Your character and the view glide through each step, walking or riding. Off: the original's step.",
    get = function() return C:DB().smoothMovement == true end,
    set = function(node, v)
        C:DB().smoothMovement = v and true or false
        C:Changed(node, "smoothMovement", v)
    end }

-- s6-world-view (round 39; the owner, 2026-10-06: "maybe add a button to the side fix 2d flicker (this is a dependancy of
-- that setting so turning it off should grey out that item but it can remain checked as the default) ... if switched into
-- 3d mode that 2d fix should be greyed out since it ALSO not only requires smooth char movement but ALSO 2d mode"): a step
-- in under Smooth Character Movement on the Motion page, on by default. Its two needs grey it with their (!) while unmet,
-- its box kept; the drawing uses it only while both are met (TK.WorldView.SmoothMovement.Fixes). Drawing only.
C.fix2dFlickerOption = { type = "toggle", name = "Fix 2D Flicker", default = true, indent = 1,
    desc = "Stops the dotted shadows flickering while the view glides in 2D.",
    requires = {
        TK.Needs("Smooth Character Movement", function() return C:DB().smoothMovement == true end),
        TK.Needs("World Renderer: Normal", function() return CS.TK.Modular.Draw.WorldRenderers.Choice == "normal" end),
    },
    get = function() return C:DB().fix2dFlicker ~= false end,
    set = function(node, v)
        C:DB().fix2dFlicker = v and true or false
        C:Changed(node, "fix2dFlicker", v)
    end }
