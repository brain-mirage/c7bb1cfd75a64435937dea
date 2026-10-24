local C = TK.GetComponent("aids")

-- s6-reprojection-cloud-3 (run 21; the owner, head note 67: an "Aids" section in the Settings menu): the Aids tab's Map
-- page, a tab of its own beside the others (core/settings.lua's S.categories), in the game and at the login screen.
-- Both switches are off by default and saved in the profile as every page's are; main.lua hands them to C#'s WorldAids,
-- and the world view draws them in every mode (Normal 2D, 3D, 3D-Sphere, the new graphics engine) with the Debug page's
-- marks. Drawing only: they are drawn from the map, its walls and the Library the client already holds, and nothing on
-- this page sends anything.
C.atLogin = true
C.category = "aids"

C.defaults = {
    unwalkableEdges = false,
    warpPoints = false,
}

C.tabs = {
    { name = "Map", args = {
        { type = "toggle", key = "unwalkableEdges", name = "Show Unwalkable Edges",
          desc = "A thin light red line along each side of a tile you cannot step across: a wall, a blocked tile or "
              .. "the map's edge. Other players and creatures, which also stop a step, are not marked." },
        { type = "toggle", key = "warpPoints", name = "Show Warp Points",
          desc = "A light purple W on each tile that warps you elsewhere, as the Library knows them: the server's own "
              .. "and those you have taken. On a map that warps you at random, only its fixed warps." },
    } },
}
