-- src/data/ports.lua
-- Data-driven port definitions. (x, y) is the INTENDED spot in world
-- coordinates; the terrain engine snaps each port to the nearest coastline and
-- flattens the ground under it, so just put them roughly next to an island.
--
-- Towns use FAMILIAR REAL Norwegian names (mostly around Bergen, plus Oslo &
-- Florø). To add a town: copy a block, give it a unique `id` (lowercase, no
-- spaces — used for save data + assets/ports/photos/<id>.png + voice files),
-- a `name`, a rough (x, y), a roof `color`, and what it `produces`.
--
-- Fields:
--   id        unique string (also the photo/voice filename)
--   name      shown in UI (Norwegian)
--   x, y      approximate location (gets snapped to a coast)
--   color     {r,g,b} accent color for the roof + destination flag
--   produces  what this town SENDS:
--               { mode = "passengers", label = "Passasjerer", icon = "passenger" }
--               { mode = "cargo",      label = "Fisk",        icon = "fish" }

return {
    {
        id    = "bergen",
        name  = "Bergen",
        x     = 1150, y = 1750,
        color = {0.85, 0.30, 0.28},
        produces = { mode = "passengers", label = "Passasjerer", icon = "passenger" },
    },
    {
        id    = "oslo",
        name  = "Oslo",
        x     = 600, y = 2100,
        color = {0.35, 0.45, 0.78},
        produces = { mode = "passengers", label = "Passasjerer", icon = "passenger" },
    },
    {
        id    = "floro",
        name  = "Florø",
        x     = 2750, y = 1250,
        color = {0.30, 0.62, 0.66},
        produces = { mode = "cargo", label = "Fisk", icon = "fish" },
    },
    {
        id    = "leroy",
        name  = "Lerøy",          -- famous for salmon → fish cargo
        x     = 2950, y = 2400,
        color = {0.55, 0.45, 0.75},
        produces = { mode = "cargo", label = "Fisk", icon = "fish" },
    },
    {
        id    = "klokkarvik",
        name  = "Klokkarvik",
        x     = 2750, y = 450,
        color = {0.90, 0.62, 0.30},
        produces = { mode = "cargo", label = "Fisk", icon = "fish" },
    },
    {
        id    = "alversund",
        name  = "Alversund",
        x     = 1150, y = 350,
        color = {0.50, 0.62, 0.40},
        produces = { mode = "passengers", label = "Passasjerer", icon = "passenger" },
    },
    {
        id    = "hjellestad",
        name  = "Hjellestad",
        x     = 1900, y = 1150,
        color = {0.90, 0.45, 0.62},
        produces = { mode = "passengers", label = "Passasjerer", icon = "passenger" },
    },
}

-- Spare/fallback town names (the old made-up ones). Not used unless you swap
-- them in above: Solhavn, Fjellvik, Blomsterøy.
