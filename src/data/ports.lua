-- src/data/ports.lua
-- Data-driven port definitions. (x, y) is the INTENDED spot in world
-- coordinates; the terrain engine snaps each port to the nearest coastline and
-- flattens the ground under it, so just put them roughly next to an island.
--
-- Fields:
--   id     unique string
--   name   shown in UI (Norwegian)
--   x, y   approximate location (gets snapped to a coast)
--   color  {r,g,b} accent color for the building roof + flag
--   cargo  the kind of goods this port likes to SEND (label + icon)

return {
    {
        id    = "solhavn",
        name  = "Solhavn",        -- "Sun Harbor"
        x     = 1150,
        y     = 1750,
        color = {0.95, 0.55, 0.25},
        cargo = { label = "Epler",  icon = "apple" },
    },
    {
        id    = "fjellvik",
        name  = "Fjellvik",       -- "Mountain Cove"
        x     = 2750,
        y     = 1250,
        color = {0.55, 0.45, 0.75},
        cargo = { label = "Fisk",   icon = "fish" },
    },
    {
        id    = "blomstero",
        name  = "Blomsterøy",     -- "Flower Island"
        x     = 2950,
        y     = 2400,
        color = {0.90, 0.40, 0.60},
        cargo = { label = "Blomster", icon = "flower" },
    },
}
