-- s6-ui-core (round 85): the XML twins' look entries (each twin's dialogs/init.lua's L.<Name>). A family's XML file holds
-- each dialog's layout as a <data key="Name"> (core/xml.md): its attributes are the entry's own values (width, height,
-- button and the sizes the dialogs component makes its parts by), its children the places the family's Lua draws the
-- parts at. Shared by the twins (interfaces/<id>/dialogs/). Drawing only: nothing here is sent.

--- The entry: the data's own single values on fns, the family's functions (a list value, which the data does not tell
--- from a child's places, the family gives itself).
return function(spec, fns)
    for k, v in pairs(spec) do
        if type(v) ~= "table" then fns[k] = v end
    end
    return fns
end
