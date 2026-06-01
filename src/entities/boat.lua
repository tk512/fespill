-- src/entities/boat.lua
-- The player's boat. Simple table-with-methods entity (no inheritance).
--
-- Movement (in the flat ground plane) is gentle and forgiving:
--   * accelerates slowly, turns slowly, never sinks
--   * bounces softly off land — and crucially can ALWAYS sail away again
--     (we only damp speed when moving INTO an obstacle, never when leaving)
--
-- Rendering is isometric and volumetric: the hull is an extruded shape that
-- rotates with the boat's heading, with a cabin box and a little wake — so it
-- reads as a 3D-ish vehicle in the SimCity-style world, not a flat sprite.

local config = require("src.config")
local Assets = require("src.assets")
local Iso    = require("src.systems.iso")

local Boat = {}
Boat.__index = Boat

-- Hull outline in local boat space (pointing along +X = "forward").
local HULL = {
    { 26,   0},  -- bow tip
    { 10, -13},  -- forward port
    {-18, -13},  -- aft port
    {-23,   0},  -- stern
    {-18,  13},  -- aft starboard
    { 10,  13},  -- forward starboard
}
local DECK_H  = 13   -- how tall the hull sits above the water
local CABIN_H = 16   -- cabin height above the deck

function Boat.new(def, x, y)
    local self = setmetatable({}, Boat)
    self.def      = def
    self.x        = x or 0
    self.y        = y or 0
    self.angle    = -math.pi / 4
    self.speed    = 0
    self.maxSpeed = def.speed
    self.accel    = def.accel
    self.turnRate = def.turn
    self.radius   = 20
    self.cargo    = {}
    self.capacity = def.capacity
    self.destX    = nil
    self.destY    = nil
    self.bumpCooldown = 0
    self.safeX, self.safeY = self.x, self.y  -- last position known to be water
    return self
end

-- Keep the boat on the water. Called by the world each frame after update():
-- if the boat has wandered onto land, send it back to the last water spot and
-- gently steer it toward open water. Never wipes the destination, so it can
-- always sail away from a shore instead of getting stuck.
local DIRS8 = { {1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1} }
function Boat:blockLand(terrain)
    if terrain:isWater(self.x, self.y) then
        self.safeX, self.safeY = self.x, self.y
        return
    end
    local S = self.radius + 8
    local nx, ny = 0, 0
    for _, d in ipairs(DIRS8) do
        if terrain:isWater(self.x + d[1] * S, self.y + d[2] * S) then
            nx, ny = nx + d[1], ny + d[2]
        end
    end
    self.x, self.y = self.safeX, self.safeY  -- back to water
    if nx ~= 0 or ny ~= 0 then
        self.angle = math.atan2(ny, nx)       -- face open water
    end
    self.speed = self.speed * config.BOUNCE_DAMPING
    self:softHit()
end

function Boat:cargoCount() return #self.cargo end
function Boat:hasRoom()    return #self.cargo < self.capacity end

function Boat:setDestination(x, y) self.destX, self.destY = x, y end
function Boat:clearDestination()   self.destX, self.destY = nil, nil end

local function angleDiff(a, b)
    local d = (b - a) % (2 * math.pi)
    if d > math.pi then d = d - 2 * math.pi end
    return d
end

function Boat:update(dt)
    self.bumpCooldown = math.max(0, self.bumpCooldown - dt)

    local throttle, steer = 0, 0
    local manual = false
    if love.keyboard.isDown("up", "w")    then throttle =  1;   manual = true end
    if love.keyboard.isDown("down", "s")  then throttle = -0.5; manual = true end
    if love.keyboard.isDown("left", "a")  then steer = -1;      manual = true end
    if love.keyboard.isDown("right", "d") then steer =  1;      manual = true end
    if manual then self:clearDestination() end

    -- Auto-steer toward a clicked destination.
    if self.destX then
        local dx, dy = self.destX - self.x, self.destY - self.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < 14 then
            self:clearDestination()
        else
            local diff = angleDiff(self.angle, math.atan2(dy, dx))
            steer = math.max(-1, math.min(1, diff * 2))
            throttle = math.min(1, dist / 120)
        end
    end

    self.angle = self.angle + steer * self.turnRate * dt

    local targetSpeed = throttle * self.maxSpeed
    if self.speed < targetSpeed then
        self.speed = math.min(targetSpeed, self.speed + self.accel * dt)
    else
        self.speed = math.max(targetSpeed, self.speed - self.accel * 1.5 * dt)
    end

    self.x = self.x + math.cos(self.angle) * self.speed * dt
    self.y = self.y + math.sin(self.angle) * self.speed * dt

    self:clampToWorld()
end

function Boat:clampToWorld()
    local r = self.radius
    local hitX = self.x < r or self.x > config.WORLD_WIDTH  - r
    local hitY = self.y < r or self.y > config.WORLD_HEIGHT - r
    self.x = math.max(r, math.min(config.WORLD_WIDTH  - r, self.x))
    self.y = math.max(r, math.min(config.WORLD_HEIGHT - r, self.y))
    if hitX or hitY then self:softHit() end
end

-- Soft circular collision (used for islands). The key fix vs. before: we only
-- slow the boat when it is moving INTO the obstacle, and we never wipe the
-- destination — so the boat can always sail back out instead of getting pinned.
function Boat:collideCircle(cx, cy, cr)
    local dx, dy = self.x - cx, self.y - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local minDist = cr + self.radius
    if dist >= minDist then return end
    if dist < 0.001 then dx, dy, dist = 1, 0, 1 end

    local nx, ny = dx / dist, dy / dist
    self.x = cx + nx * minDist     -- push out to the surface
    self.y = cy + ny * minDist

    local vx = math.cos(self.angle) * self.speed
    local vy = math.sin(self.angle) * self.speed
    local into = vx * nx + vy * ny  -- < 0 means heading into the obstacle
    if into < 0 then
        -- reflect the heading away from the surface, soften the speed
        local rvx = vx - 2 * into * nx
        local rvy = vy - 2 * into * ny
        self.angle = math.atan2(rvy, rvx)
        self.speed = self.speed * config.BOUNCE_DAMPING
        self:softHit()
    end
end

function Boat:softHit()
    if self.bumpCooldown == 0 then
        Assets.playSfx("bump")
        self.bumpCooldown = 0.35
    end
end

-- ── Drawing (isometric, volumetric) ────────────────────────────────────────
local function rot(px, py, a, ox, oy)
    local c, s = math.cos(a), math.sin(a)
    return ox + px * c - py * s, oy + px * s + py * c
end

function Boat:draw()
    -- If a PNG is provided, draw it as a big SIDE-PROFILE billboard: long and
    -- low (a kid's boat drawing), spanning a couple of tiles, anchored on the
    -- water and flipped horizontally to face the way it's heading. (One angle
    -- for now; left/right/forward frames can come later.)
    local sprite = self.def.sprite and Assets.image("boats/" .. self.def.sprite)
    if sprite then
        local sx, sy = Iso.project(self.x, self.y, 0)
        local want = (self.def.spriteWidth or config.BOAT_SPRITE_WIDTH)
        local scale = want / sprite:getWidth()
        local flip = (math.cos(self.angle) < 0) and -1 or 1   -- face travel dir
        -- soft shadow on the water
        love.graphics.setColor(0, 0, 0, 0.16)
        love.graphics.ellipse("fill", sx, sy + 2, want * 0.45, want * 0.16)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprite, sx, sy, 0, scale * flip, scale,
            sprite:getWidth() / 2, sprite:getHeight() * 0.82)
        return
    end
    self:drawVolumetric()
end

function Boat:drawVolumetric()
    local c = config.colors

    -- Ground-space hull outline (rotated by heading, around the boat position).
    -- For each point we keep both a sea-level and a deck-level projection.
    local base, deck = {}, {}
    for _, p in ipairs(HULL) do
        local gx, gy = rot(p[1], p[2], self.angle, self.x, self.y)
        local bx, by = Iso.project(gx, gy, 0)
        local dx, dy = Iso.project(gx, gy, DECK_H)
        base[#base + 1] = { bx, by }
        deck[#deck + 1] = { dx, dy }
    end

    -- Soft shadow / wake on the water.
    local sxc, syc = Iso.project(self.x, self.y, 0)
    love.graphics.setColor(0, 0, 0, 0.16)
    love.graphics.ellipse("fill", sxc, syc + 4, 26, 13)
    self:drawWake(sxc, syc)

    -- Hull side walls (draw every edge; hidden faces get painted over by the deck).
    love.graphics.setColor(c.boat_hull_dk)
    local n = #base
    for i = 1, n do
        local a, b = i, (i % n) + 1
        love.graphics.polygon("fill",
            deck[a][1], deck[a][2], deck[b][1], deck[b][2],
            base[b][1], base[b][2], base[a][1], base[a][2])
    end

    -- Deck (top face).
    local deckPoly = {}
    for i = 1, n do deckPoly[#deckPoly + 1] = deck[i][1]; deckPoly[#deckPoly + 1] = deck[i][2] end
    love.graphics.setColor(c.boat_hull)
    love.graphics.polygon("fill", deckPoly)
    love.graphics.setColor(c.boat_deck)
    love.graphics.polygon("line", deckPoly)

    -- Cabin: a little box sitting on the deck, in the player boat's color.
    self:drawCabin(c)
end

function Boat:drawWake(sxc, syc)
    if self.speed < 25 then return end
    local a = math.min(0.35, self.speed / self.maxSpeed * 0.35)
    -- two streaks trailing the stern (opposite the heading)
    local bx, by = rot(-26, 0, self.angle, self.x, self.y)
    local px, py = Iso.project(bx, by, 0)
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.ellipse("fill", px, py + 2, 10, 5)
    love.graphics.setColor(1, 1, 1, a * 0.6)
    love.graphics.ellipse("fill", (px + sxc) / 2, (py + syc) / 2 + 2, 7, 3)
end

function Boat:drawCabin(c)
    local cabin = { {6, -8}, {6, 8}, {-10, 8}, {-10, -8} }
    local lo, hi = {}, {}
    for _, p in ipairs(cabin) do
        local gx, gy = rot(p[1], p[2], self.angle, self.x, self.y)
        local lx, ly = Iso.project(gx, gy, DECK_H)
        local hx, hy = Iso.project(gx, gy, DECK_H + CABIN_H)
        lo[#lo + 1] = { lx, ly }
        hi[#hi + 1] = { hx, hy }
    end
    local col = self.def.color or c.boat_cabin
    -- walls
    love.graphics.setColor(col[1] * 0.7, col[2] * 0.7, col[3] * 0.7)
    local n = #lo
    for i = 1, n do
        local a, b = i, (i % n) + 1
        love.graphics.polygon("fill",
            hi[a][1], hi[a][2], hi[b][1], hi[b][2],
            lo[b][1], lo[b][2], lo[a][1], lo[a][2])
    end
    -- roof
    local roof = {}
    for i = 1, n do roof[#roof + 1] = hi[i][1]; roof[#roof + 1] = hi[i][2] end
    love.graphics.setColor(col)
    love.graphics.polygon("fill", roof)
end

return Boat
