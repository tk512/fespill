-- src/data/ports.lua
-- Data-driven port definitions. (x, y) is the INTENDED spot in world
-- coordinates; the terrain engine snaps each port to the nearest coastline and
-- flattens the ground under it, so just put them roughly next to an island.
--
-- Towns use FAMILIAR REAL Norwegian names (mostly around Bergen, plus Oslo &
-- Florø). To add a town: copy a block, give it a unique `id` (lowercase, no
-- spaces — used for save data + assets/ports/photos/<id>.png + voice files),
-- a `name`, a rough (x, y) near an island, a roof `color`, what it `produces`,
-- and a city `size` (tiny / small / medium / large — see config.CITY_SIZES).
--
-- Fields:
--   id        unique string (also the photo/voice filename)
--   name      shown in UI (Norwegian)
--   x, y      approximate location (gets snapped to a coast)
--   color     {r,g,b} accent color for the roof + destination flag
--   size      how big the city looks (buildings drawn around it)
--   master    (optional) the harbour master's name, shown on the dock screen
--             nameplate ("Havnesjef <master>"). Matches the portrait in
--             assets/ports/portraits/<id>.png. Omit to show plain "Havnesjef".
--   produces  what this town SENDS:
--               { mode = "passengers", label = "Passasjerer", icon = "passenger" }
--               { mode = "cargo",      label = "Fisk",        icon = "fish" }

return {
    {
        id    = "bergen",
        name  = "Bergen",
        master = "Arne",
        x     = 3600, y = 3500,        -- SE coast of the big NW island
        color = {0.85, 0.30, 0.28},
        size  = "large",
        produces = { mode = "passengers", label = "Passasjerer", icon = "passenger" },
    },
    {
        id    = "oslo",
        name  = "Oslo",
        master = "Donald Duck",
        x     = 9000, y = 5400,        -- NW coast of the big SE island
        color = {0.35, 0.45, 0.78},
        size  = "large",
        produces = { mode = "passengers", label = "Passasjerer", icon = "passenger" },
    },
    {
        id    = "floro",
        name  = "Florø",
        master = "Håkon",
        x     = 8700, y = 3400,        -- south coast of the NE island
        color = {0.30, 0.62, 0.66},
        size  = "medium",
        produces = { mode = "cargo", label = "Fisk", icon = "fish" },
    },
    {
        id    = "leroy",
        name  = "Lerøy",              -- famous for salmon → fish cargo
        master = "Farfar",
        x     = 3500, y = 5300,        -- NE coast of the SW island
        color = {0.55, 0.45, 0.75},
        size  = "medium",
        produces = { mode = "cargo", label = "Fisk", icon = "fish" },
    },
    {
        id    = "alversund",
        name  = "Alversund",
        master = "Samuel",
        x     = 6200, y = 3000,        -- south coast of the N-mid island
        color = {0.50, 0.62, 0.40},
        size  = "small",
        produces = { mode = "passengers", label = "Passasjerer", icon = "passenger" },
    },
    {
        id    = "hjellestad",
        name  = "Hjellestad",
        master = "Arne",
        x     = 7800, y = 5050,        -- south coast of the center island
        color = {0.90, 0.45, 0.62},
        size  = "small",
        produces = { mode = "passengers", label = "Passasjerer", icon = "passenger" },
    },
    {
        id    = "klokkarvik",
        name  = "Klokkarvik",
        master = "Farmor",
        x     = 5200, y = 5650,        -- the tiny island, S-mid
        color = {0.90, 0.62, 0.30},
        size  = "tiny",
        produces = { mode = "cargo", label = "Fisk", icon = "fish" },
    },
    {
        id    = "florida",
        name  = "Florida",
        master = "Vlad Niki",
        x     = 5100, y = 4300,        -- big harbour on the central-sea island
        color = {0.95, 0.55, 0.20},
        size  = "large",
        produces = { mode = "passengers", label = "Passasjerer", icon = "passenger" },
    },
}

-- Spare/fallback town names (the old made-up ones). Not used unless you swap
-- them in above: Solhavn, Fjellvik, Blomsterøy.
