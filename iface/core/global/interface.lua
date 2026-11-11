-- s6-ui-core (the five parts' step 2a, the head's go of 2026-10-25;
-- docs/user-related/research/client-architecture/2026-10-25-global-interface-and-five-parts.md, section 3.3 item 1): the
-- Global Interface's declaration, the panels every interface shows and none owns. The interface registry reads it beside
-- each interface's interface.lua (core/interfaces.lua's T:Load); an entry has an interface panel's fields
-- (interfaces/modern/interface.lua's header), and each is shared: in use in every interface, on in every first profile
-- but the default interface's (which keeps its components' defaults), and listed with the shown interface's panels.
-- Until this step they were the default interface's list's: the same ids, components, pages, switches and places, so the
-- saved settings and positions are the same. It draws nothing and sends nothing.

return { panels = {
    -- the world view: the client's world, in a frame every interface shows and edit mode moves
    -- (components/worldview/main.lua); its drawing is the world renderer's, and each interface may give it a look
    { id = "worldview", name = "World View", category = "World", component = "worldview", node = "worldview", switch = "enabled", place = "worldview", shared = true },
    -- s6-ui-core (round 60; the owner, 2026-10-06: "an interface item that is used/can be used on all interfaces so it
    -- should be under All interfaces in ui as a subpage Menu"): the menu button (core/global/components/menubutton), off by its
    -- component's default, so off in the default interface's first profile and on in the others'
    { id = "menubutton", name = "Menu", category = "Buttons", component = "menubutton", node = "menubutton", switch = "enabled",
      place = "menubutton", shared = true },
} }
