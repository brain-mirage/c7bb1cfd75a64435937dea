# The UI's XML layout files

`core/xml.lua` (TK.Xml) builds a frame tree from an XML file with the frame API of `core/frame.lua`, call for call and
in the file's order, so a frame built from XML is the frame the same Lua calls would have built. The XML says what the
frames are, where they sit and how they look; the Lua beside it keeps the scripts (what happens on a press, an update,
an event). The host reads the files (`H:ReadXml`, `LuaApi.Xml.cs`); building them sends nothing.

The first users are the XML twins of the 7.x, 5.x and Modern interfaces (`interfaces/xml/<id>/`), which Settings >
Experimental > "Enable XML Interface" switches to (below).

## Loading a file

```lua
local L = TK.Xml.Data("main.xml")            -- the file's top <data> values, nothing built
local ui = TK.Xml.Load("main.xml", {         -- builds every top element in order
    scripts = scripts,                       -- the functions call="..." names
    elements = E,                            -- the interface's own elements (below)
    parent = frame,                          -- the parent of top elements without parent="..."
})
ui.frame                                     -- a top element's key
ui.roots                                     -- the top frames in order
ui:New("TemplateName", parent, "FrameName")  -- an instance of a template, later (or in a <run>, during the build)
ui:New("Row", list, "Row1", nil, { slot = 1 }) -- with its own values, @with in the template (a row's slot, its label)
```

A file name is relative to the Lua file that loads it (`"../shared.xml"` works; nothing outside the Lua folder). A file
is read once per Lua state. Frames a panel's file builds are the panel's (they go when it is turned off); a template's
instance is the panel's that makes it (a shared file's template, as Modern's portrait, is each user's own). An
instance's `@root` is its own top element; the build that made it during a `<run>` keeps its own `@root` and `@with`.

## Elements

| element | makes | notes |
|---|---|---|
| `<ui>` | the root | every file's |
| `<frame>` | `CreateFrame(type, name, parent, template)` | `type` (default `Frame`), `name`, `parent` (a global's name or `@ref`; default the enclosing frame), `template` (a frame template of `core/frame.lua`) |
| `<texture>` | `parent:CreateTexture(name, layer, template, sublevel)` | inside a frame; `parent="@ref"` makes it on another frame (its key still on the enclosing one) |
| `<text>` | `parent:CreateFontString(name, layer, template, sublevel)` | as `<texture>` |
| `<template name="...">` | nothing; its one element is what `from="..."` takes | at the file's top only |
| `<include file="..."/>` | nothing; the file's templates become this file's | |
| `<do .../>` | its capitalised attributes, as calls, at that place | `<do Hide=""/>` |
| `<on script="OnX" call="Fn"/>` | `SetScript("OnX", scripts.Fn)` | `hook="true"`: `HookScript` |
| `<run call="Fn"/>` | `scripts.Fn(obj, build, with)` at that place in the build | the Lua's own steps, in order; `build:New` makes a template's instances there; `with`: the instance's values (`New`'s) |
| `<data key="k" .../>` | a value on the enclosing frame (or the build, at the top) | see Data |

Any other element is the interface's own (`opts.elements[tag]`, below).

## Attributes

- **lowercase** attributes are the loader's: `name`, `key`, `from`, `type`, `parent`, `layer`, `sublevel`, `template`,
  `call`, `script`, `hook`, `file`.
- **Capitalised** attributes are method calls, in the order written: `Size="55, 15"` is `obj:SetSize(55, 15)` (the
  method itself when it exists, else `Set` + its name: `Hide=""` is `obj:Hide()`, `AllPoints="@parent"` is
  `obj:SetAllPoints(parent)`).
- `key="name"` puts the object on the frame it is built in (or on the build, at the top) and lets `@name` refer to it;
  `key="name[]"` appends it to that list instead.
- `name="$parentCooldown"`: `$parent` is the parent's name (a template's instance named by `New` gives its children
  names of their own); `name="@with.cooldown"` is a value.
- `from="A, B"` builds the templates' calls and children first, then the element's own; the element's own `name`,
  `type`, `layer`... win over theirs.

## Values

`true`, `false`, `nil`, numbers (`12`, `-3`, `0x8F`), text, and references: `@parent` (the parent of the object a call
is made on; for an interface's element, the frame it is made in), `@root` (the top element being built: a template's
instance, or a frame or an interface's element at the file's top), `@with` (the values `New` gave the instance), `@key`
(an object or a value of this build with that key), and a field of any of them: `@SIZES.portrait` (a number a top
`<data>` holds for the XML and its Lua alike), `@parent.title` (a widget's part), `@with.label`. A comma-separated
value is a list of arguments (a call) or a list (a data value).

## Data

`<data key="PLACE" value="830, 736"/>` is the list `{ 830, 736 }`; `<data key="ART" file="TIME.EPF" x="0"/>` is the
table `{ file = "TIME.EPF", x = 0 }`. Elements inside a `<data>` are its list, in order (`<data key="ROWS"><row .../>
<row .../></data>`); a `<data key="k">` inside one is its field `k` instead. `TK.Xml.Data(file)` reads a file's top data
without building anything: what a Lua file needs at load (its tables, the places its Layout uses).

## An interface's own elements

`opts.elements` maps a tag to `function(parent, attrs, ctx)`, which gets the lowercase attributes as values and returns
what it made; its capitalised attributes are then calls on that, and its children are built in it. 7.x's twin gives
`<picture>`, `<bold>`, `<tiles>`, `<outline>` (`interfaces/xml/7x/elements.lua`) and its side panel's kit
`<invenbutton>`, `<scrollbar>`, `<arrow>`, `<textpane>` (`interfaces/xml/7x/panels/side/elements.lua`, on the original's kit). 5.x's twin gives
`<picture>`, `<fill>`, `<skintext>`, `<scrollbar>`, `<press>` (`interfaces/xml/5x/elements.lua`) and its side panel's
`<textbox>`. Modern's twin gives its widgets (`interfaces/xml/modern/elements.lua`: `<label>`, `<button>`, `<window>`,
`<tab>`, `<check>`, `<slotart>`, `<scrollarea>`...), each the call the original makes.

## The XML interfaces (round 85)

- The twins live in `interfaces/xml/<id>/`: each holds the files of `interfaces/<id>/` whose layout it makes XML (that
  layout as XML, the file's Lua its scripts); a file it does not hold is the original's, loaded as it is. The originals
  are not changed.
- Their registration is the originals': `interface.lua`, each `panels/<p>/settings.lua` and Modern's `manifest.json`
  are not in the twins. So the components, their settings, the profiles, edit mode's places and the bindings are the
  same in both forms.
- With the box on, a require of `interfaces.<id>.<rest>` loads `interfaces/xml/<id>/<rest>` when the twin has that
  file (`LuaHost.XmlInterfaces`, `FormPath`); the shared code (`interfaces/screen.lua`, `interfaces/original/`) is
  shared by both.
- The box (`TK.Interfaces:SetXml`) switches live: the open windows are noted and closed, the interface panels unloaded,
  their modules dropped, the form set, the panels loaded again from the other form, the windows opened again. Nothing is
  sent (the windows reopen as the server's views do, which carry no request).
- The panels' frames are their `main.xml`'s (and the side panel's pages' `selflook.xml`, `look.xml`, `options.xml`);
  what a panel makes many of alike (item rows and cells, spell rows, gear, option rows) is made by its Lua in a loop
  from the file's data, as a `<run>` at its place.
- The dialogs' windows are the dialogs component's (its renderers make them, the same for every look); an interface's
  look only sizes and places their parts. The twin's look takes each family's sizes, pictures and places from the
  family's XML data (`dialogs/npc.xml`... beside `npc.lua`; `dialogs/look.xml` what every window shares;
  `interfaces/xml/entry.lua`, shared by the twins, makes an entry from a dialog's data: its attributes are the entry's
  values, its children the places, so a value that is not the entry's sits in a child).
- The skin's screen, font and standard window are `skin.xml`'s.
- An interface's own login screen is its twin's alone (`interfaces/xml/<id>/screens/`, round 86: 7.x's and 5.x's
  `title.xml`, made by the twins' shared `interfaces/xml/title.lua`), shown with Experimental's Original Login Screens
  (`core/login.lua`, "an interface's own login screen").
- Wire: a twin's scripts are the original's code; where a layout file holds what decides an input's path (a control's
  rectangle, which presses a frame claims), the file's header says so, as the Lua's comments do.
