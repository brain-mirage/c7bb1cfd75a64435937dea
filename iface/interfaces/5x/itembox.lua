-- 5.33 has server-text help only. The requested local 7.5.2 sheet uses 5.33's font and help-box palette.
-- Decision: docs/user-related/decisions/2026-10-06-5x-local-item-help.md. Input remains core/game/itemhelp.lua's.
return require("interfaces.original.itembox")({ skin = require("interfaces.5x.skin"),
    help = require("interfaces.5x.help"), name = "TK5xItemBox", fill = 1 })
