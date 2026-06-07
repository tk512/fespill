-- src/systems/iso.lua
-- 2:1 isometric projection (SimCity 2000 / dimetric "diamond" look).
--
-- We keep all game logic — movement, collision, distances — in a flat
-- "ground plane" of (gx, gy) coordinates (the same world the boat sails in).
-- This module is the ONLY place that converts between that ground plane and
-- what you see on screen. Everything that draws calls Iso.project(); anything
-- that needs to turn a mouse click back into a world spot calls Iso.unproject().
--
--   ground (gx, gy, gz)  --project-->  screen-ish iso (x, y)
--   iso (x, y)           --unproject-> ground (gx, gy)   (assumes gz = 0)
--
-- gz is height: bigger gz lifts a point UP the screen, which is how land,
-- buildings and the boat's deck get their volume.

local Iso = {}

-- Half-width / quarter-height factors give the classic 2:1 diamond.
Iso.SX = 0.5    -- horizontal squash
Iso.SY = 0.25   -- vertical squash
Iso.HEIGHT = 1.0 -- how strongly gz lifts things on screen

-- Ground -> iso screen space (before the camera transform is applied).
function Iso.project(gx, gy, gz)
    gz = gz or 0
    local x = (gx - gy) * Iso.SX
    local y = (gx + gy) * Iso.SY - gz * Iso.HEIGHT
    return x, y
end

-- Iso screen space -> ground (assuming the point sits on the water, gz = 0).
-- Used to turn a mouse click into a destination for the boat.
function Iso.unproject(x, y)
    -- From the two project() equations:
    --   x = (gx - gy) * SX      ->  gx - gy = x / SX
    --   y = (gx + gy) * SY      ->  gx + gy = y / SY
    local a = x / Iso.SX   -- gx - gy
    local b = y / Iso.SY   -- gx + gy
    local gx = (a + b) / 2
    local gy = (b - a) / 2
    return gx, gy
end

-- Painter's-algorithm depth key. Things with a LARGER value are nearer the
-- viewer (lower on screen) and must be drawn later so they overlap correctly.
function Iso.depth(gx, gy)
    return gx + gy
end

-- ── Multi-tile footprints (for sprite objects) ─────────────────────────────
-- An object occupies a w×h block of tiles whose top-left tile is (tx, ty)
-- (1-based; tile i spans ground [(i-1)*T, i*T]). These helpers turn that into
-- the geometry a sprite or placeholder needs: the four ground corners, the
-- ground center (where a sprite's base anchors), and the on-screen diamond
-- width (so a PNG can be scaled to exactly cover the footprint).
-- Reused output table: objects are drawn one at a time and consume the result
-- immediately, so a single shared table avoids allocating one per draw (= per
-- visible object per frame), which was a big source of GC churn.
local _fp = {}
function Iso.footprint(tx, ty, w, h, T)
    local gx0, gx1 = (tx - 1) * T, (tx - 1 + w) * T
    local gy0, gy1 = (ty - 1) * T, (ty - 1 + h) * T
    local f = _fp
    f.gx0, f.gx1, f.gy0, f.gy1 = gx0, gx1, gy0, gy1
    f.cx, f.cy = (gx0 + gx1) / 2, (gy0 + gy1) / 2     -- ground center
    -- diamond width on screen (before zoom) = T * (w + h) / 2
    local rx = (gx1 - gy0) * Iso.SX
    local lx = (gx0 - gy1) * Iso.SX
    f.width = rx - lx
    return f
end

-- Depth of a footprint = its front (south) corner, so it's painted after the
-- tiles it stands on and the tiles behind it.
function Iso.footprintDepth(tx, ty, w, h, T)
    return Iso.depth((tx - 1 + w) * T, (ty - 1 + h) * T)
end

return Iso
