-- s6-ui-core (round 85; the owner, 2026-10-11: three interfaces "split into xml for the design, layout etc, and lua will
-- control the actual scripting like WOW does it", and "he will need to implement the xml handling as well"): the UI's XML
-- layout files. A Lua file loads one (TK.Xml.Load), and the loader builds what it describes with the WoW-style frame API
-- (core/frame.lua), call for call and in the file's order, so a frame built from XML is the frame the same Lua calls
-- would have built. The format, for the owner and plugin authors: core/xml.md, beside this file. The host reads a file
-- (H:ReadXml, LuaApi.Xml.cs); the XML interfaces (7.x, 5.x, Modern) are the first users.
--
-- Drawing only: building frames sends nothing. What a frame's scripts do is its Lua's.

local H = __tk

local X = {}
TK.Xml = X

local unpack = table.unpack or unpack
local parsed = {} -- a file's path (from the Lua folder) -> its parse tree, read once per Lua state

-- ----- files -----

--- A path from the Lua folder: file relative to folder, its ".." steps resolved (none may climb out of the Lua folder).
local function join(folder, file)
    local parts = {}
    for part in (folder .. "/" .. file):gmatch("[^/]+") do
        if part == ".." then
            if #parts == 0 then error("the XML file " .. file .. " is outside the Lua folder", 3) end
            parts[#parts] = nil
        elseif part ~= "." then
            parts[#parts + 1] = part
        end
    end
    return table.concat(parts, "/")
end

--- The folder (from the Lua folder) of the Lua file running level levels up (debug.getinfo's levels).
local function folderOf(level)
    local source = (debug.getinfo(level + 1, "S") or {}).source or ""
    source = source:gsub("^@", ""):gsub("\\", "/"):gsub("^lua/", "")
    return source:match("^(.*)/[^/]*$") or ""
end

--- A file's parse tree (read once).
local function read(path)
    local tree = parsed[path]
    if tree then return tree end
    tree = H:ReadXml(path)
    if type(tree) ~= "table" then error("XML: " .. tostring(tree), 0) end
    if tree.tag ~= "ui" then error("XML: " .. path .. ": its root element is <" .. tostring(tree.tag) .. ">, not <ui>", 0) end
    tree.path = path
    parsed[path] = tree
    return tree
end

-- ----- values -----

--- Where a node is, for an error: its file and line.
local function where(node, ctx) return (ctx and ctx.path or "?") .. ":" .. tostring(node.line) end

--- The object "@name" names: @parent (parent when given: an interface element's, the frame it is made in; else owner's
--- parent, the object a call is made on; else the build's), @root (the top element being built), @with (the values the
--- Lua gave the instance being made: build:New's with), or the one with that key.
local function object(name, ctx, owner, parent)
    if name == "parent" then return parent or owner and owner:GetParent() or ctx.parent end
    if name == "root" then return ctx.root end
    if name == "with" then return ctx.with end
    return ctx.keys[name]
end

--- One value as written: true, false, nil, a number (decimal or 0x hex), "@name" (an object of this build: @parent, @root,
--- or one with that key, as object() says; "@name.field" a field of it: a top <data>'s value, a widget's part as
--- @parent.title), else the text itself.
local function value(s, ctx, owner, parent)
    if s == "true" then return true end
    if s == "false" then return false end
    if s == "nil" then return nil end
    local n = tonumber(s)
    if n then return n end
    if s:sub(1, 1) == "@" and ctx then
        local ref = s:sub(2)
        if ref == "parent" or ref == "root" or ref == "with" then return object(ref, ctx, owner, parent) end
        local o = ctx.keys[ref]
        local first, fields = ref:match("^([^.]+)%.(.+)$")
        if o == nil and first then
            o = object(first, ctx, owner, parent)
            for field in fields:gmatch("[^.]+") do
                if type(o) ~= "table" then o = nil break end
                o = o[field]
            end
        end
        if o == nil then error(ctx.path .. ": no object with key " .. ref, 0) end
        return o
    end
    return s
end

--- A comma-separated list of values (each trimmed): the arguments of a method call. Returns them and their count.
local function args(s, ctx, owner)
    local out, n = {}, 0
    if s == "" then return out, 0 end
    for part in (s .. ","):gmatch("(.-),") do
        n = n + 1
        out[n] = value(part:match("^%s*(.-)%s*$"), ctx, owner)
    end
    return out, n
end

--- A data value: one value, or a list for a comma-separated one.
local function datum(s)
    if s:find(",", 1, true) then
        local list, n = args(s)
        list.n = nil
        return list, n
    end
    return value(s)
end

-- ----- building -----

--- Calls each capitalised attribute of node on obj, in the file's order: Name="a, b" is obj:Name(a, b), or
--- obj:SetName(a, b) when obj has no Name method (Size="20, 10" is SetSize(20, 10)). Lowercase attributes are the
--- loader's own (name, key, from...).
local function calls(obj, node, ctx)
    for _, attr in ipairs(node.order) do
        if attr:match("^%u") then
            local method = obj[attr]
            if type(method) ~= "function" then method = obj["Set" .. attr] end
            if type(method) ~= "function" then error(where(node, ctx) .. ": no method " .. attr .. " on a " .. node.tag, 0) end
            local a, n = args(node.attrs[attr], ctx, obj)
            method(obj, unpack(a, 1, n))
        end
    end
end

--- A <data> element's value (and so of each element in it): its value="...", else a table of its other attributes (the
--- key is where it goes, not in it) with its child elements' values as its list, in order; a <data key="k"> child is
--- its field k instead.
local function data(node)
    if node.attrs.value ~= nil then return (datum(node.attrs.value)) end
    local t = {}
    for k, v in pairs(node.attrs) do
        if k ~= "key" or node.tag ~= "data" then t[k] = datum(v) end
    end
    for _, child in ipairs(node) do
        if child.tag == "data" and child.attrs.key then t[child.attrs.key] = data(child) else t[#t + 1] = data(child) end
    end
    return t
end

--- Puts an object (or a data value) where its key says: on its holder (the frame it is built in, or the build's result
--- for a top element); "name[]" appends it to the holder's list name. Also known to "@key" by its key.
local function place(holder, key, obj, ctx)
    if not key then return end
    local list = key:match("^(.-)%[%]$")
    if list then
        holder[list] = holder[list] or {}
        table.insert(holder[list], obj)
    else
        holder[key] = obj
        ctx.keys[key] = obj
    end
end

local build

--- The template elements a node inherits (its from="A, B"), each the one element a <template> holds.
local function templates(node, ctx)
    local out = {}
    for name in (node.attrs.from or ""):gmatch("[^,%s]+") do
        local t = ctx.templates[name]
        if not t then error(where(node, ctx) .. ": no template " .. name, 0) end
        out[#out + 1] = t
    end
    return out
end

--- The first value of a creation argument (type, layer...) along the templates, the node's own first.
local function creation(node, chain, attr)
    if node.attrs[attr] ~= nil then return node.attrs[attr] end
    for i = #chain, 1, -1 do
        local v = chain[i].attrs[attr]
        if v ~= nil then return v end
    end
    return nil -- one value always (a call's argument)
end

--- The frame a frame or region is made on: its parent="..." (a global frame's name or @ref) when given, else the frame it
--- is built in. Its key still goes on the frame it is built in (a region on another frame: Modern's look window's portrait
--- on its profile view, made in the window's order).
local function parentOf(node, chain, ctx, parent)
    local named = creation(node, chain, "parent")
    if not named then return parent end
    local p = value(named, ctx)
    if type(p) == "string" then p = _G[p] end
    return p
end

--- A frame's or region's name: "$parent" in it is its parent's name ("$parentCooldown" under TKActionBar1Button1); one
--- that starts with @ is a value (name="@with.cooldown": a name the Lua making the instance gives).
local function nameOf(node, chain, parent, ctx)
    local name = creation(node, chain, "name")
    if type(name) == "string" and name:sub(1, 1) == "@" then name = value(name, ctx) end
    if type(name) == "string" and name:find("$parent", 1, true) then
        name = name:gsub("%$parent", parent and parent:GetName() or "")
    end
    return name
end

--- The whole template chain of a node, depth first (a template's own from= before it), the node not included.
local function chainOf(node, ctx, out)
    out = out or {}
    for _, t in ipairs(templates(node, ctx)) do
        chainOf(t, ctx, out)
        out[#out + 1] = t
    end
    return out
end

--- The script function a node's call="..." names (opts.scripts').
local function script(node, ctx)
    local name = node.attrs.call
    local fn = ctx.scripts and ctx.scripts[name]
    if type(fn) ~= "function" then error(where(node, ctx) .. ": no script function " .. tostring(name), 0) end
    return fn
end

--- What a node's children do to obj, in the file's order: build the elements, run <do>, <on> and <run>, set <data>.
local function children(obj, node, ctx)
    for _, child in ipairs(node) do
        local tag = child.tag
        if tag == "do" then
            calls(obj, child, ctx)
        elseif tag == "on" then
            -- hook="true": after the script the frame has (HookScript), else in its place (SetScript)
            if child.attrs.hook == "true" then
                obj:HookScript(child.attrs.script, script(child, ctx))
            else
                obj:SetScript(child.attrs.script, script(child, ctx))
            end
        elseif tag == "run" then
            -- the Lua's own step at this place in the build: script(obj, build, with), in order with the calls around it
            -- (the build: its keys so far, and New for its templates' instances; with: the instance's, New's)
            script(child, ctx)(obj, ctx.ui, ctx.with)
        elseif tag == "data" then
            place(obj, child.attrs.key, data(child), ctx)
        else
            build(child, obj, ctx, obj)
        end
    end
end

local REGION = { texture = true, text = true }

--- Builds one element under parent (nil: no parent), holder getting its key. Returns what it made.
function build(node, parent, ctx, holder)
    local tag = node.tag
    local chain = chainOf(node, ctx)
    local make = ctx.elements and ctx.elements[tag]
    local obj
    if tag == "frame" then
        local p = parentOf(node, chain, ctx, parent)
        obj = CreateFrame(creation(node, chain, "type") or "Frame", nameOf(node, chain, p, ctx), p,
                          creation(node, chain, "template"))
        -- a panel's frames go with the panel when it is turned off or its interface's form is switched
        -- (TK.Components:Unload): CreateFrame gives a root made by shared code (this file) to no one, so the loader does
        if ctx.owner then TK.Components:Adopt(obj, ctx.owner, ctx.panel) end
    elseif REGION[tag] then
        local p = parentOf(node, chain, ctx, parent)
        if not p then error(where(node, ctx) .. ": a <" .. tag .. "> needs a frame to be in", 0) end
        local method = tag == "texture" and "CreateTexture" or "CreateFontString"
        obj = p[method](p, nameOf(node, chain, p, ctx), creation(node, chain, "layer"),
                        creation(node, chain, "template"), tonumber(creation(node, chain, "sublevel")))
    elseif make then
        -- an element the loading Lua gives (opts.elements): it gets the lowercase attributes as values and makes what it
        -- makes; the capitalised ones are then calls on that, as on any element
        local attrs = {}
        for _, n in ipairs(chain) do
            for k, v in pairs(n.attrs) do if k:match("^%l") then attrs[k] = value(v, ctx, nil, parent) end end
        end
        for k, v in pairs(node.attrs) do if k:match("^%l") then attrs[k] = value(v, ctx, nil, parent) end end
        obj = make(parent, attrs, ctx)
        place(holder, node.attrs.key, obj, ctx)
        if type(obj) == "table" then
            ctx.root = ctx.root or obj -- (a top element's: @root is the window an interface's <window> makes)
            calls(obj, node, ctx)
            children(obj, node, ctx)
        end
        return obj
    else
        error(where(node, ctx) .. ": unknown element <" .. tostring(tag) .. ">", 0)
    end
    ctx.root = ctx.root or obj
    place(holder, creation(node, chain, "key"), obj, ctx)
    for _, t in ipairs(chain) do
        calls(obj, t, ctx)
        children(obj, t, ctx)
    end
    calls(obj, node, ctx)
    children(obj, node, ctx)
    return obj
end

--- A file's templates (and its includes', first) by name, into ctx.templates.
local function collect(tree, ctx, seen)
    seen = seen or {}
    if seen[tree.path] then return end
    seen[tree.path] = true
    for _, node in ipairs(tree) do
        if node.tag == "include" then
            collect(read(join(tree.path:match("^(.*)/[^/]*$") or "", node.attrs.file)), ctx, seen)
        elseif node.tag == "template" then
            local proto = node[1]
            if not (node.attrs.name and proto) or node[2] then
                error(tree.path .. ":" .. tostring(node.line) .. ": a <template> has a name and one element", 0)
            end
            ctx.templates[node.attrs.name] = proto
        end
    end
end

--- The build's context: the file, its templates, the scripts and elements the Lua gives, and who owns what is made.
local function context(path, opts, depth)
    local tree = read(path)
    local ctx = { path = path, tree = tree, templates = {}, keys = {}, scripts = opts.scripts, elements = opts.elements,
                  parent = opts.parent }
    ctx.owner, ctx.panel = TK.Components:Owner(depth + 1) -- the panel whose Lua loads the file (build's frames: Adopt)
    collect(tree, ctx)
    return ctx
end

-- ----- the API -----

--- Builds a layout file: file is relative to the calling Lua file's folder ("main.xml", "../templates.xml"). opts:
---   scripts   the table the file's <on call="..."> names its functions in (the panel's Lua, usually its component)
---   elements  the loading Lua's own elements: name -> function(parent, attrs, ctx) returning what it made
---   parent    the parent of the file's top elements (a frame's parent="..." names its own); none by default
--- Every top element (but <template>, <include>) is built in the file's order. Returns the build: each top element's and
--- top <data>'s key on it, and roots, the top frames in order; build:New(...) makes a template's instance later.
function X.Load(file, opts)
    opts = opts or {}
    local ctx = context(join(folderOf(2), file), opts, 2)
    local ui = { roots = {} }
    ctx.ui = ui
    -- (not a tail call: X.New counts the stack to its caller's caller, the Lua making the instance)
    ui.New = function(_, name, parent, frameName, holder, with)
        return (X.New(ctx, name, parent, frameName, holder, with))
    end
    for _, node in ipairs(ctx.tree) do
        local tag = node.tag
        if tag == "data" then
            place(ui, node.attrs.key, data(node), ctx)
        elseif tag ~= "template" and tag ~= "include" then
            ctx.root = nil
            local obj = build(node, opts.parent, ctx, ui)
            ui.roots[#ui.roots + 1] = obj
        end
    end
    return ui
end

--- A layout file's top <data> values by their keys, without building anything (file as X.Load's): what a Lua file needs
--- before its frames are made (a table its functions read at once, the places its Layout uses).
function X.Data(file)
    local path = join(folderOf(2), file)
    local tree = read(path)
    local out = {}
    for _, node in ipairs(tree) do
        if node.tag == "data" and node.attrs.key then out[node.attrs.key] = data(node) end
    end
    return out
end

--- An instance of a template of a build's file (ui:New(name, parent, frameName, holder, with)): built under parent, named
--- frameName when given (else the template's name="..."), its key put on holder (parent by default); with (optional) is
--- a table of its own values, @with.field in the template (a row's text, a slot's place). Returns it.
function X.New(ctx, name, parent, frameName, holder, with)
    local proto = ctx.templates[name]
    if not proto then error(ctx.path .. ": no template " .. tostring(name), 2) end
    local node = proto
    if frameName then
        -- the same element under another name: a shallow copy whose name attribute is the one asked for (its attributes
        -- copied, not inherited: an interface's element reads them all with pairs)
        local attrs = {}
        for k, v in pairs(proto.attrs) do attrs[k] = v end
        attrs.name = frameName
        node = setmetatable({ attrs = attrs }, { __index = proto })
        for i, child in ipairs(proto) do node[i] = child end
    end
    -- the instance is its own @root, and its with is @with; one made by a <run> while a build goes on gives that build its
    -- own back after
    local outer, outerWith = ctx.root, ctx.with
    ctx.root, ctx.with = nil, with
    -- the instance is the panel's that makes it now, as a frame CreateFrame makes is (Components:FrameOwner), not the one
    -- that loaded the file: a shared file's template (Modern's portrait) is made by each panel that uses it
    ctx.owner, ctx.panel = TK.Components:Owner(3)
    local obj = build(node, parent, ctx, holder or parent or ctx.ui)
    ctx.root, ctx.with = outer, outerWith
    return obj
end

return X
