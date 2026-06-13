-- src/entities/pirate.lua
-- The AI pirate ship: a rare, scary hunter that chases the player and lobs slow
-- cannonballs (BOOM!). Tuning lives in config.PIRATE. Deliberately gentle:
--   * slower than the player's boat, so it can always be outrun / dodged
--   * cannonballs are slow + telegraphed (you can sail out of the way)
--   * each hit costs a little gold (the world handles the gold + shake + sound)
--   * gives up when you stay far away long enough, or when you're out of gold
--
-- Like the player boat, it lives in the flat ground plane; only draw() knows
-- about the isometric projection. The world inserts it into the depth-sorted
-- pass so islands occlude it correctly, and calls drawBalls() afterwards.

local config = require("src.config")
local Assets = require("src.assets")
local Iso    = require("src.systems.iso")

local Pirate = {}
Pirate.__index = Pirate

local P = config.PIRATE

local function angleDiff(a, b)
    local d = (b - a) % (2 * math.pi)
    if d > math.pi then d = d - 2 * math.pi end
    return d
end

function Pirate.new(x, y, playerMaxSpeed)
    local self = setmetatable({}, Pirate)
    self.x, self.y = x, y
    self.angle    = 0
    self.speed    = 0
    self.maxSpeed = playerMaxSpeed * P.SPEED_FRAC
    self.turnRate = 1.5
    self.radius   = 26
    self.state    = "chase"                 -- "chase" | "retreat"
    self.fireT    = P.FIRE_INTERVAL * 0.7   -- a moment before the first shot
    self.balls    = {}
    self.farT     = 0                       -- how long you've been out of reach
    self.muzzle   = 0                       -- muzzle-flash timer
    self.dead     = false
    return self
end

-- Make the pirate break off and sail away (called when you're broke, or after
-- it loses interest). It vanishes once far enough (see update()).
function Pirate:flee()
    self.state = "retreat"
end

function Pirate:update(dt, boat, terrain, onHit)
    local dx, dy = boat.x - self.x, boat.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    -- steer toward the boat (chase) or away from it (retreat)
    local targetAng = (self.state == "retreat") and math.atan2(-dy, -dx) or math.atan2(dy, dx)
    local diff = angleDiff(self.angle, targetAng)
    self.angle = self.angle + math.max(-1, math.min(1, diff * 2)) * self.turnRate * dt

    -- accelerate toward top speed (a touch faster when fleeing)
    local target = self.maxSpeed * (self.state == "retreat" and 1.15 or 1.0)
    self.speed = self.speed + (target - self.speed) * math.min(1, dt * 1.5)

    -- move; if land is ahead, veer to find open water (islands shield the boat)
    local nx = self.x + math.cos(self.angle) * self.speed * dt
    local ny = self.y + math.sin(self.angle) * self.speed * dt
    if terrain:isWater(nx, ny) then
        self.x, self.y = nx, ny
    else
        self.angle = self.angle + 1.2 * dt
        self.speed = self.speed * 0.9
    end
    self.x = math.max(20, math.min(config.WORLD_WIDTH - 20, self.x))
    self.y = math.max(20, math.min(config.WORLD_HEIGHT - 20, self.y))

    -- cannon fire (only while chasing and within range)
    self.muzzle = math.max(0, self.muzzle - dt)
    if self.state == "chase" then
        self.fireT = self.fireT - dt
        if self.fireT <= 0 and dist < P.FIRE_RANGE then
            self.fireT = P.FIRE_INTERVAL
            self:fire(boat)
        end
    end

    -- advance cannonballs; a ball that reaches the boat scores a hit
    for i = #self.balls, 1, -1 do
        local b = self.balls[i]
        b.life = b.life + dt
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        local bdx, bdy = boat.x - b.x, boat.y - b.y
        local hitR = boat.radius + P.BALL_RADIUS
        if (bdx * bdx + bdy * bdy) < hitR * hitR then
            table.remove(self.balls, i)
            if onHit then onHit() end
        elseif b.life > b.plan + 0.3 then
            table.remove(self.balls, i)         -- splashed harmlessly (missed)
        end
    end

    -- losing interest / vanishing
    if self.state == "chase" then
        if dist > P.GIVEUP_DIST then self.farT = self.farT + dt else self.farT = 0 end
        if self.farT > P.GIVEUP_TIME then self:flee() end
    elseif dist > P.DESPAWN_DIST then
        self.dead = true
    end
end

-- Lob a cannonball toward where the boat is heading, and BOOM.
function Pirate:fire(boat)
    local dx, dy = boat.x - self.x, boat.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local plan = dist / P.BALL_SPEED
    local bvx, bvy = math.cos(boat.angle) * boat.speed, math.sin(boat.angle) * boat.speed
    local tx = boat.x + bvx * plan * 0.8        -- partial lead (so it's still dodge-able)
    local ty = boat.y + bvy * plan * 0.8
    local ang = math.atan2(ty - self.y, tx - self.x)
    local mx = self.x + math.cos(self.angle) * 30   -- fire from the bow
    local my = self.y + math.sin(self.angle) * 30
    self.balls[#self.balls + 1] = {
        x = mx, y = my,
        vx = math.cos(ang) * P.BALL_SPEED, vy = math.sin(ang) * P.BALL_SPEED,
        life = 0, plan = plan,
    }
    self.muzzle = 0.14
    Assets.playSfx("cannon", 0.85)
end

-- ── Drawing (isometric) ─────────────────────────────────────────────────────
local HULL = { { 26, 0 }, { 10, -13 }, { -20, -13 }, { -26, 0 }, { -20, 13 }, { 10, 13 } }

function Pirate:draw()
    local t = love.timer.getTime()
    local z = math.sin(t * 1.6) * 2                  -- gentle bob
    local co, si = math.cos(self.angle), math.sin(self.angle)
    local function rot(px, py) return self.x + (px * co - py * si), self.y + (px * si + py * co) end

    local base, deck = {}, {}
    for _, p in ipairs(HULL) do
        local wx, wy = rot(p[1], p[2])
        local bx, by = Iso.project(wx, wy, z)
        local dx, dy = Iso.project(wx, wy, z + 14)
        base[#base + 1] = { bx, by }
        deck[#deck + 1] = { dx, dy }
    end

    local sxc, syc = Iso.project(self.x, self.y, 0)
    love.graphics.setColor(0, 0, 0, 0.20)
    love.graphics.ellipse("fill", sxc, syc + 4, 30, 15)

    -- dark hull sides + deck
    love.graphics.setColor(0.16, 0.11, 0.08)
    local n = #base
    for i = 1, n do
        local a, b = i, (i % n) + 1
        love.graphics.polygon("fill", deck[a][1], deck[a][2], deck[b][1], deck[b][2],
            base[b][1], base[b][2], base[a][1], base[a][2])
    end
    local poly = {}
    for i = 1, n do poly[#poly + 1] = deck[i][1]; poly[#poly + 1] = deck[i][2] end
    love.graphics.setColor(0.26, 0.18, 0.12); love.graphics.polygon("fill", poly)
    love.graphics.setColor(0.10, 0.07, 0.05); love.graphics.polygon("line", poly)

    -- mast + tattered black sail with a skull (screen-space billboard)
    local mx, my = Iso.project(self.x, self.y, z + 14)
    love.graphics.setColor(0.10, 0.07, 0.05)
    love.graphics.setLineWidth(3); love.graphics.line(mx, my, mx, my - 54); love.graphics.setLineWidth(1)
    love.graphics.setColor(0.13, 0.13, 0.16)
    love.graphics.polygon("fill", mx - 21, my - 47, mx + 21, my - 47, mx + 16, my - 14, mx - 16, my - 14)
    -- skull
    love.graphics.setColor(0.86, 0.86, 0.9); love.graphics.circle("fill", mx, my - 33, 6)
    love.graphics.setColor(0.10, 0.10, 0.13)
    love.graphics.circle("fill", mx - 2.4, my - 34, 1.5); love.graphics.circle("fill", mx + 2.4, my - 34, 1.5)
    love.graphics.rectangle("fill", mx - 2, my - 29, 4, 2)
    -- a little skull-and-crossbones flag at the top
    love.graphics.setColor(0.06, 0.06, 0.07)
    love.graphics.polygon("fill", mx, my - 54, mx + 17, my - 51, mx, my - 47)
    love.graphics.setColor(0.85, 0.85, 0.9); love.graphics.circle("fill", mx + 7, my - 51, 1.6)

    -- muzzle flash + smoke just after firing
    if self.muzzle > 0 then
        local bx, by = rot(30, 0)
        local fx, fy = Iso.project(bx, by, z + 6)
        local s = self.muzzle / 0.14
        love.graphics.setColor(0.72, 0.72, 0.72, s * 0.5); love.graphics.circle("fill", fx, fy - 3, 9 * s)
        love.graphics.setColor(1, 0.78, 0.30, s); love.graphics.circle("fill", fx, fy, 10 * s)
        love.graphics.setColor(1, 0.5, 0.12, s * 0.85); love.graphics.circle("fill", fx, fy, 6 * s)
    end
    love.graphics.setColor(1, 1, 1)
end

-- Cannonballs arc through the air (a parabolic screen height) over the water.
function Pirate:drawBalls()
    for _, b in ipairs(self.balls) do
        local pr = math.min(1, b.life / math.max(0.01, b.plan))
        local h = math.sin(pr * math.pi) * 55
        local sx, sy = Iso.project(b.x, b.y, h)
        local gx, gy = Iso.project(b.x, b.y, 0)
        love.graphics.setColor(0, 0, 0, 0.18); love.graphics.ellipse("fill", gx, gy + 2, 7, 3)
        love.graphics.setColor(0.08, 0.08, 0.10); love.graphics.circle("fill", sx, sy, P.BALL_RADIUS * 0.6 + 2)
        love.graphics.setColor(0.24, 0.24, 0.28); love.graphics.circle("fill", sx - 2, sy - 2, P.BALL_RADIUS * 0.4)
    end
    love.graphics.setColor(1, 1, 1)
end

return Pirate
