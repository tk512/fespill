-- src/data/boats.lua
-- Data-driven boat definitions. Add a new boat by copying a block and
-- changing the values — no game code needs to change.
--
-- Fields:
--   id        unique string used in save data and unlock logic
--   name      shown in UI (Norwegian)
--   speed     top speed in pixels/second
--   accel     how quickly it reaches top speed (higher = snappier)
--   turn      turning speed in radians/second (lower = gentler for kids)
--   capacity  how many cargo units it can carry
--   cost      gold needed to unlock (0 = available from the start)
--   sprite    optional PNG in assets/boats/ (falls back to placeholder art)
--   color     {r,g,b} hull color used by the placeholder drawing

return {
    {
        id       = "starter_boat",
        name     = "Vesle-Tuten",      -- "Little Tug"
        speed    = 140,
        accel    = 90,
        turn     = 1.8,
        capacity = 2,
        cost     = 0,
        sprite   = "boat1.png",
        color    = {0.85, 0.30, 0.25},
    },
    {
        id       = "fishing_boat",
        name     = "Fiskebåten",       -- "The Fishing Boat"
        speed    = 175,
        accel    = 110,
        turn     = 2.0,
        capacity = 4,
        cost     = 60,
        sprite   = "boat2.png",
        color    = {0.30, 0.55, 0.85},
    },
    {
        id       = "cargo_ship",
        name     = "Lasteskipet",      -- "The Cargo Ship"
        speed    = 210,
        accel    = 70,
        turn     = 1.4,
        capacity = 8,
        cost     = 180,
        sprite   = "boat3.png",
        color    = {0.95, 0.70, 0.20},
    },
}
