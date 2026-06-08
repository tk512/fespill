-- src/config.lua
-- One central place for tuning numbers and colors.
-- A non-programmer can tweak gameplay feel by editing values here.

local config = {}

-- ── Startup ─────────────────────────────────────────────────────────────
-- Set to true to launch fullscreen (what your child plays with).
-- Keep false while developing so you get a normal resizable window.
config.START_FULLSCREEN = true

-- ── World / rendering ───────────────────────────────────────────────────
config.WORLD_WIDTH  = 12000  -- size of the sailable ocean (in ground units)
config.WORLD_HEIGHT = 8000   -- BIG: lots of open sea to explore between islands

-- Isometric tile grid. The ground is a FLAT 2:1 iso tile map (water/sand/
-- grass/rock) with curvy coastlines, designed to take a CC0 pixel tileset
-- (assets/tiles/<type>.png). TILE is one tile's size in ground units.
config.TILE       = 64

-- ── Procedural terrain ─────────────────────────────────────────────────────
-- SimCity-2000-style VARIED topography: a layered noise height field (broad
-- mountains + medium hills + fine roughness), shaped by island masks, then
-- "terraced" so most of each elevation band snaps flat with slope transitions
-- between. The result is plains, valleys, gradual mountain ranges and flat
-- coasts in some places / cliffs in others — lots of buildable flat ground at
-- many different heights, not one boring plateau and not constant bumps.
config.WORLD_SEED   = 1337   -- change for a different map (F6 regenerates)
config.LAND_THRESH  = 0.42   -- island mask + edge noise above this = land
config.COAST_SCALE  = 520    -- scale of coastline wiggle (bigger = smoother)
config.COAST_NOISE  = 0.22   -- how much the noise frays the coastline
config.COVER_SCALE  = 720    -- scale of grass-vs-rock land cover patches
config.ROCK_THRESH  = 0.62   -- cover noise above this becomes rocky ground

-- Coastline detail: a coastal tile is filled with this many sub-pixels per side
-- (so the land/water edge is a jagged, noisy PIXEL line rather than one big
-- diamond block). Higher = finer/smoother but more to draw. 4–6 looks retro.
config.COAST_PIXELS = 10     -- higher = finer SVGA-ish coast (more to draw)
config.COAST_JAGGED = 0.6    -- how much noise frays the pixel shoreline (0 = clean steps)

-- Forests: thick woodland that covers contiguous regions of tiles.
config.FOREST_SCALE   = 360    -- bigger = larger forests
config.FOREST_THRESH  = 0.54   -- lower = more / bigger forests
config.FOREST_DENSITY = 6      -- trees drawn per forest tile (thick)

-- Island masks define where the land is and how big each island is. These are
-- MASSIVE and spread far apart so there's real open ocean to explore between
-- them. Each one roughly hosts the matching port/city in src/data/ports.lua.
config.ISLANDS = {
    { x = 2600, y = 2600, radius = 1800 },  -- Bergen   (huge, NW)
    { x = 6200, y = 2200, radius = 1100 },  -- Alversund (N-mid)
    { x = 9600, y = 2600, radius = 1400 },  -- Florø    (NE)
    { x = 7800, y = 4400, radius = 900  },  -- Hjellestad (center-E)
    { x = 2600, y = 6000, radius = 1300 },  -- Lerøy    (SW)
    { x = 5200, y = 6200, radius = 750  },  -- Klokkarvik (tiny, S-mid)
    { x = 10000,y = 6200, radius = 1800 },  -- Oslo     (huge, SE)
}

-- ── Fog of war (exploration) ───────────────────────────────────────────────
-- The world starts as dark "unknown" zones. As the boat sails, the area around
-- it is revealed for good (saved), so discovering the map is a surprise. A
-- bigger boat (future) can carry a brighter lantern = larger reveal radius.
config.FOG_CELL        = 256   -- reveal granularity in ground units (4 tiles)
config.FOG_REVEAL      = 760   -- how far around the boat gets lit up

-- ── Cities (buildings drawn around a port to show its size) ────────────────
-- Each port in ports.lua has a `size`; these map size -> how many houses to
-- scatter around the harbour and how far out they spread (in tiles).
config.CITY_SIZES = {
    tiny   = { houses = 4,  spread = 4  },
    small  = { houses = 9,  spread = 6  },
    medium = { houses = 18, spread = 9  },
    large  = { houses = 40, spread = 15 },
}

config.CAMERA_MIN_ZOOM = 0.55   -- furthest out (wheel down) — wide overview
config.CAMERA_MAX_ZOOM = 3.2    -- closest in (wheel up) — lots of detail
config.CAMERA_DEFAULT_ZOOM = 1.4 -- starting view: close enough to see detail
-- Mid-90s style: the camera does NOT follow the boat. Scroll by pushing the
-- mouse to the screen edges (or right-drag); press C to recenter on the boat.
config.EDGE_SCROLL_MARGIN = 38  -- px from a screen edge that triggers scrolling
config.EDGE_SCROLL_SPEED  = 950 -- scroll speed (screen px / second)

-- ── Gameplay feel (kept gentle on purpose — see CLAUDE.md "child-friendly") ─
config.PICKUP_RADIUS  = 95    -- how close to a harbour the boat must get to dock
                              -- (measured from the dock point in the water just
                              -- in front of the harbour; smaller = must arrive closer)
config.BOAT_SPRITE_WIDTH = 140 -- on-screen width of the boat sprite (≈2 tiles)
config.BOUNCE_DAMPING = 0.45  -- how soft collisions feel (0 = dead stop, 1 = bouncy)

-- ── Audio ───────────────────────────────────────────────────────────────
config.MUSIC_VOLUME = 0.35
config.SFX_VOLUME   = 0.6
config.AUDIO_ON     = true

-- ── Palette (retro VGA SimCity 2000 vibe: muted, earthy, cosy) ─────────────
-- Colors are {r, g, b} in 0..1. Land tiles use {top, lip, dot}; lip is the
-- shaded coastal face, dot is the dither texture. Deliberately desaturated and
-- a touch dark — not bright modern web-game colors.
config.colors = {
    water_top    = {0.31, 0.49, 0.60},  -- shallow / near land (muted teal-blue)
    water_deep   = {0.21, 0.37, 0.50},  -- open sea
    wave         = {0.52, 0.64, 0.70},  -- soft, not white
    foam         = {0.86, 0.90, 0.89},  -- surf at the waterline

    sand  = { top = {0.76, 0.69, 0.49}, lip = {0.60, 0.53, 0.36}, dot = {0.70, 0.63, 0.44} },
    grass = { top = {0.49, 0.55, 0.31}, lip = {0.36, 0.42, 0.22}, dot = {0.44, 0.50, 0.27} },
    rock  = { top = {0.56, 0.52, 0.45}, lip = {0.42, 0.39, 0.33}, dot = {0.51, 0.47, 0.41} },

    -- sprite-object placeholders (muted)
    lot          = {0.66, 0.62, 0.53},
    building_wall= {0.80, 0.74, 0.62},
    building_dk  = {0.60, 0.52, 0.43},
    road         = {0.46, 0.44, 0.40},
    dock_top     = {0.55, 0.42, 0.28},
    dock_side    = {0.40, 0.30, 0.20},
    stone        = {0.56, 0.55, 0.50},
    tree_trunk   = {0.36, 0.27, 0.17},
    tree_leaf    = {0.28, 0.39, 0.21},
    tree_leaf_hi = {0.37, 0.47, 0.27},
    rock_light   = {0.56, 0.54, 0.49},
    rock_dark    = {0.40, 0.39, 0.35},

    -- boats / ships (muted)
    boat_hull    = {0.72, 0.32, 0.27},
    boat_hull_dk = {0.52, 0.22, 0.18},
    boat_deck    = {0.80, 0.70, 0.50},
    boat_cabin   = {0.86, 0.82, 0.72},

    -- ui
    text         = {0.96, 0.95, 0.90},
    text_dark    = {0.16, 0.16, 0.18},
    gold         = {0.88, 0.74, 0.34},
    panel        = {0.16, 0.18, 0.22},
}

-- Building roof/wall accent colors for harbor variety (muted retro tones).
config.BUILDING_COLORS = {
    {0.64, 0.36, 0.30},  -- brick red
    {0.46, 0.48, 0.52},  -- slate
    {0.72, 0.64, 0.46},  -- tan
    {0.50, 0.52, 0.36},  -- olive
    {0.40, 0.46, 0.50},  -- blue-grey
    {0.66, 0.56, 0.40},  -- ochre
}

-- A few ship accent colors used for ambient/docked vessels (muted).
config.SHIP_COLORS = {
    {0.70, 0.34, 0.28}, {0.34, 0.46, 0.58}, {0.74, 0.62, 0.34},
    {0.42, 0.54, 0.40}, {0.62, 0.50, 0.56},
}

return config
