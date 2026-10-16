-- Picture viewer sources for the packs' pictures (s6-spell-icons): what TK.UI.PictureViewer (core/viewer.lua) shows of
-- one family, drawn as the map draws it (__tk:GetArtPicture). For every window that lists the game's pictures: the spell
-- icon editor's Effects, Creatures, Tiles, Objects and Icons, and the Library's monster, NPC and item pages
-- (s6-library-pages).
--
--   local src = TK.UI.ArtSource("creature", { colour = 0, label = function(id, frames) return "..." end })
--   viewer:SetSource(src)
--
-- The families:
--   "effect"    the effect animations (EFFECT.TBL's ids), those that draw; animated
--   "creature"  monsters, NPCs and animals by their MONSTER.DNA table (appearance - 0x8000), walking (standing when they
--               have no walking frames); animated, four facings (0 north, 1 east, 2 south, 3 west), and their other
--               animations (stand, attack, hurt, actions 2-5; round 3)
--   "tile"      the map's ground tiles; still, or playing their colour cycling (water; round 3)
--   "object"    the map's static objects (trees, walls, signs), all their layers; still, or playing their colour
--               cycling (round 3)
--   "icon"      the item icons (ITEM.EPF's frames, the art:icon/n keys); still
-- Beyond the viewer's calls a source has src.family, src.id(i) (picture i's id in its family) and src.index(id) (nil when
-- the family has no such picture).

local H = __tk
local W = TK.UI

local NAMES = { effect = "Effect", creature = "Creature", tile = "Tile", object = "Object", icon = "Icon" }
local FACINGS = { [0] = "North", [1] = "East", [2] = "South", [3] = "West" }

--- A source of one family's pictures. opts: colour (a creature's shade), label(id, frames) (the tooltip's text).
function W.ArtSource(family, opts)
    opts = opts or {}
    local src = { family = family }
    local ids, count
    if family == "icon" then
        count = H:MacroIconCount() -- s6-macros' count of the packs' item icons; icon n is picture n + 1
    else
        ids = H:GetArtIds(family)
        count = #ids
    end
    local index -- id -> picture, made at the first ask

    local function label(id, frames)
        if opts.label then return opts.label(id, frames) end
        return NAMES[family] .. " " .. id .. ((frames or 0) > 1 and (" (" .. frames .. " frames)") or "")
    end

    function src.count() return count end

    function src.id(i) return ids and ids[i] or i - 1 end

    function src.index(id)
        if id == nil then return nil end
        if not ids then return (id >= 0 and id < count) and id + 1 or nil end
        if not index then
            index = {}
            for i, v in ipairs(ids) do index[v] = i end
        end
        return index[id]
    end

    function src.picture(i, facing, animation)
        local id = src.id(i)
        if family == "icon" then
            local key = "art:icon/" .. id
            local ok, w, h = H:GetArtSize(key)
            if not ok then return "" end
            return key, w, h, label(id, 1), 1
        end
        local key, w, h, frames = H:GetArtPicture(family, id, { facing = facing, colour = opts.colour, action = animation })
        return key, w, h, label(id, frames), frames, key == "" and tostring(id) or nil
    end

    if family ~= "icon" then
        function src.now(i, first, last, facing, animation)
            return H:GetArtPicture(family, src.id(i), { facing = facing, colour = opts.colour, action = animation, first = first,
                last = last, animate = true })
        end
    end
    if family == "creature" then
        src.facings, src.facingNames = 4, FACINGS
        function src.animations(i, facing) return H:GetArtAnimations(family, src.id(i), facing or 2) end
    end
    return src
end
