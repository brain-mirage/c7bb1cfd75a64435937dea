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

-- s6-ui-core (round 85; the owner, 2026-10-11: "To select these you click a box in experimental called Enable XML
-- Interface ... the onyl visisble change anywhere settings wise is that checkbox"): Experimental > Misc's switch between
-- the interfaces' two forms, the originals and their XML twins (core/interfaces.lua, "the XML form"). A computer setting,
-- as the interface is; it applies at once (TK.Interfaces:SetXml) and sends nothing.
local misc = TK.MiscNode.tabs[1].args
misc[#misc + 1] = { type = "toggle", name = "Enable XML Interface", default = false, machine = true,
    desc = "The interfaces built from XML layouts and Lua scripts. They look and act as the originals.",
    get = function() return TK.Interfaces:Xml() end,
    set = function(_, on) TK.Interfaces:SetXml(on == true) end }
-- s6-ui-core (round 86; the owner, 2026-10-12: the 7.x and 5.x interfaces' own login and character screens behind a
-- setting beside Enable XML Interface, off by default; decision 2026-10-12-original-pregame-screens): the interface's own
-- login screen in place of ours (core/login.lua, "an interface's own login screen"). A computer setting; it applies at
-- once and sends nothing.
misc[#misc + 1] = { type = "toggle", name = "Original Login Screens", default = false, machine = true,
    desc = "With Enable XML Interface: 7.x's and 5.x's own title and login. Escape there opens Settings.",
    get = function() return TK.Machine:Get().originalScreens == true end,
    set = function(_, on)
        TK.Machine:Get().originalScreens = on == true
        TK.Login:ApplyScreens()
    end }
