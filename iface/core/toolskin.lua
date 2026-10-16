-- s6-devtools (round 5; the interface separation's step 5: docs/development/interface-separation.md 5.15, open question
-- 53, decision 2026-10-05-original-kit-and-tool-skin): the tools' skin, the colours and panel finish our tools draw with in
-- every interface (the settings window, edit mode, the game menu, the pre-game screens, the Library, the macro and map
-- windows, the popups, prompts and menus). TK.UI's widgets draw with it (core/widgets.lua); an interface draws its own
-- with its own skin (TK.UI.With). The values are the ones the tools and Modern shared until the split (s6-ui-core's
-- round 49 finish), so nothing looks different; a restyle of Modern (interfaces/modern/skin.lua) no longer moves the
-- tools.

local S = {}
TK.ToolSkin = S

S.gold = { 1, 0.82, 0 }
S.white = { 1, 1, 1 }
S.grey = { 0.5, 0.5, 0.5 }
-- Opaque: blending is in linear colour space, so even 6% see-through lets white text behind a dark panel show.
-- A window or panel is a cool charcoal shaded lighter at the top (tk:panel-fill), with a shallow band of light behind a
-- window's title; an inner pane is a darker charcoal recess; the edges, header rules, menus, fields and scroll bars are
-- quieter to match.
S.panelBg = { 0.13, 0.135, 0.15, 1 }
S.panelFill = "tk:panel-fill"
S.panelEdge = { 0.42, 0.42, 0.45, 1 }
S.innerBg = { 0.09, 0.095, 0.11, 0.75 }
S.innerEdge = { 0.26, 0.27, 0.30, 1 }
S.titleBand = { height = 30, color = { 0.17, 0.17, 0.185, 1 } }
S.headerRule = { 0.30, 0.29, 0.25, 1 }
S.menuBg = { 0.11, 0.115, 0.13, 1 }
S.menuHighlight = { 0.32, 0.27, 0.15, 0.65 }
S.fieldBg = { 0.065, 0.07, 0.085, 0.6 }
S.fieldEdge = { 0.30, 0.31, 0.34, 1 }
S.buttonGrey = { 0.27, 0.28, 0.30, 1 }
S.buttonText = { 0.90, 0.80, 0.55 }
S.red = { 0.55, 0.06, 0.06, 1 }
-- s6-ui-core (round 61): a tab (W.Tab), the settings window's colours: dark, the chosen one lighter
S.tabBg = { 0.18, 0.18, 0.2, 1 }
S.tabChosenBg = { 0.42, 0.42, 0.46, 1 }
-- s6-ui-core (round 62): an icon slot (W.SlotArt): its box, an item's edge, an action button's brighter edge
S.slotBg = { 0.25, 0.25, 0.28, 0.9 }
S.slotEdge = { 0.6, 0.56, 0.45, 1 }
S.slotActionEdge = { 0.78, 0.74, 0.62, 1 }
-- The see-through finish (core/widgets.lua: the UI transparency): the tools' windows follow it, as they did with Modern's
-- (open question 53: kept as they draw today until the owner answers; s6-optimize's audit of round 53, item 1).
S.seeThrough = true

return S
