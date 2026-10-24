-- s6-modular-g (interfaces, phase 2; docs/development/interfaces.md, section 2 "The settings window"): the interface
-- is the computer's and a switch applies at once (the owner's hotfix of 2026-10-06; s6-interface-5x round 13's hotfix:
-- core/interfaces.lua T:SwitchTo, the UI made again in place; nothing reconnects or sends).
-- s6-interface-5x (round 12; the owner, 2026-10-05, through the head): the Interface tab's General page, first on the tab
-- and at the login screen too (TK.Panels:GroupRoots, listTop): the interface the tab shows, Active, Reset. General's old
-- Interfaces page is gone; its looks (the dialogs', the cursors'), purely visual, were on the Graphics Styles page (Asset
-- Styles) and since s6-ui-core round 83 are the General tab's Interface page's Looks tab, their keys kept
-- (components/interface/settings.lua).

local C = TK.GetComponent("interfaces")

C.defaults = {}
C.category = "interface"
C.atLogin = true

-- s6-interface-5x (round 11): in the order the player sees them (Modern, 7.x, 5.x: TK.Interfaces:InOrder)
local function interfaces()
    local out = {}
    for _, t in ipairs(TK.Interfaces:InOrder()) do out[#out + 1] = { value = t.id, text = t.name or t.id } end
    return out
end

-- The page's tree entry: "General", first on the Interface tab whatever interface it shows.
C.title = "General"
C.listTop = true

local function viewed() return TK.Interfaces:Get(TK.Panels:Viewed()) end

C.tabs = {
    { name = "General", args = {
        -- s6-interface-5x (round 12; the owner, 2026-10-05, through the head): one row: the interface the tab shows (the
        -- dropdown only shows its pages, it never switches), whether it is the active one (ticking it switches to it at
        -- once: TK.Interfaces:SwitchTo, the owner's hotfix of 2026-10-06, no restart), and its Reset
        -- (TK.Interfaces:AskReset: the shown interface's own profile, after a question). Settings changed meanwhile go to
        -- the active interface's profile, whichever list shows (mixing). Nothing is sent by any of them.
        { type = "row", args = {
            { type = "select", name = "Interface", values = interfaces, machine = true, rowWidth = 180,
              desc = "The interface whose panels are listed here. Choosing one does not switch to it.",
              get = function() return TK.Panels:Viewed() end,
              set = function(_, v) TK.Panels:View(v) end },
            -- ticked for the interface in use (round 13, Astra's final review of round 12); ticking another switches to it
            -- at once (round 13's hotfix)
            { type = "toggle", name = "Active", machine = true, rowWidth = 100,
              desc = "The interface the client uses, with its own profiles and keys.",
              get = function() return TK.Panels:Viewed() == TK.Interfaces:Active().id end,
              set = function(_, on) if on then TK.Interfaces:SwitchTo(TK.Panels:Viewed()) end end },
            { type = "execute", name = "Reset", desc = "All of the shown interface's settings back to its defaults.",
              func = function() TK.Interfaces:AskReset(TK.Panels:Viewed()) end },
        } },
        { type = "description", width = "full", name = "Ticking Active switches to it now. Key Bindings has Next Interface." },
    } },
}

-- s6-ui-core (round 86; the owner, 2026-10-12: the 7.x and 5.x interfaces' own login and character screens behind a
-- setting in Experimental, off by default; decision 2026-10-12-original-pregame-screens): the interface's own login screen
-- in place of ours (core/login.lua, "an interface's own login screen"). A computer setting; it applies at once and sends
-- nothing. (Round 115: the "Enable XML Interface" box beside it is gone, the XML interfaces being the only ones.)
local misc = TK.MiscNode.tabs[1].args
misc[#misc + 1] = { type = "toggle", name = "Original Login Screens", default = false, machine = true,
    desc = "7.x's and 5.x's own title and login. Escape there opens Settings.",
    get = function() return TK.Machine:Get().originalScreens == true end,
    set = function(_, on)
        TK.Machine:Get().originalScreens = on == true
        TK.Login:ApplyScreens()
    end }
-- s6-reprojection (round 63; the graphics plan, section 7, "The box"): the new graphics engine, built as a twin of the
-- current one, in Experimental, off by default. A computer setting; it applies at once (the world renderers
-- swap engines, TK.Machine:ApplyGraphics applies it at load) and sends nothing: only the drawing changes.
misc[#misc + 1] = { type = "toggle", name = "Enable New Graphics Engine", default = false, machine = true,
    desc = "The new graphics engine, in place of the current one where it has the mode (3D for now). It draws the same picture.",
    get = function() return TK.Machine:Get().newGraphicsEngine == true end,
    set = function(_, on)
        TK.Machine:Get().newGraphicsEngine = on == true
        TK.Machine:ApplyGraphicsEngine()
    end }
-- s6-reprojection-cloud-3 (head note 51; the owner, 2026-10-23, on the still-missing list's item 32, the graphics
-- system choice: "put it in experimental"): the graphics system Unity's player starts on, Direct3D 11 by default. Unity
-- picks it once, when it starts, so the launcher (project/launcher, MR-TK.exe) reads it at the next start and passes
-- Unity -force-d3d11, -force-d3d12 or -force-vulkan. A computer setting; nothing changes until then, and nothing is
-- sent.
local graphicsSystems = { { value = "d3d11", text = "Direct3D 11" }, { value = "d3d12", text = "Direct3D 12" },
                          { value = "vulkan", text = "Vulkan" } }
misc[#misc + 1] = { type = "select", name = "Graphics System", default = "d3d11", machine = true,
    desc = "Applies at the next start. If the one chosen does not start, the next start is on Direct3D 11.",
    values = graphicsSystems,
    get = function() return TK.Machine:Get().graphicsSystem or "d3d11" end,
    set = function(_, value) TK.Machine:Get().graphicsSystem = value end }
-- A start on the one chosen that did not come up (the launcher's trial file, LuaApi.GraphicsSystemFailed): the choice
-- goes back to Direct3D 11, and the player is told once.
local failed, running = __tk:GraphicsSystemFailed()
if failed then
    TK.Machine:Get().graphicsSystem = "d3d11"
    TK.Machine:MarkDirty()
    local function nameOf(value)
        for _, system in ipairs(graphicsSystems) do
            if system.value == value then return system.text end
        end
        return value
    end
    TK.Popup(nameOf(failed) .. " did not start, so the client started on " .. nameOf(running) .. ". Graphics System "
        .. "(Experimental > Misc) is set back to Direct3D 11.", "Graphics System")
end
