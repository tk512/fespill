-- src/entities/port.lua
-- A harbor the boat visits to load / deliver cargo.
--
-- It's a MULTI-TILE sprite object (3x3 tiles). The terrain engine snaps it to
-- a coastline and FLATTENS the ground under it (so the buildings stand level),
-- and tells it which way the open sea is (`seaDx, seaDy`) so the dock,
-- breakwater and docked ships face the water.
--
-- The placeholder is a detailed little harbor: warehouse + roof, a second
-- building, a crane, a stone breakwater reaching into the sea, and a few
-- docked ships of different colors. Drop in assets/ports/<id>.png to replace
-- the whole 3x3 footprint with one sprite.

local config  = require("src.config")
local Iso     = require("src.systems.iso")
local Objects = require("src.systems.objects")

local Port = {}
Port.__index = Port

Port.FOOTPRINT = 4  -- tiles per side (a small harbor town)

function Port.new(def)
    local self = setmetatable({}, Port)
    self.def   = def
    self.id    = def.id
    self.name  = def.name
    self.x     = def.x          -- intended location; terrain snaps it to coast
    self.y     = def.y
    self.color = def.color or {0.8, 0.6, 0.4}
    self.bob   = #def.id
    self.w, self.h = Port.FOOTPRINT, Port.FOOTPRINT
    self.tx, self.ty = 1, 1
    self.buildZ = 0
    self.seaDx, self.seaDy = 0, 1
    return self
end

-- Called by terrain after it snaps the port to a coast + flattens the site.
function Port:placeAt(tx, ty, cx, cy, buildZ, seaDx, seaDy)
    self.tx, self.ty = tx, ty
    self.x, self.y = cx, cy
    self.buildZ = buildZ
    self.seaDx, self.seaDy = seaDx, seaDy
end

function Port:update(dt) self.bob = self.bob + dt end

-- The spot the boat actually pulls up to: out in the WATER in front of the
-- harbour (the port building itself sits on land, which the boat can't reach).
-- seaDx/seaDy is the unit direction toward open water; push out past the
-- flattened footprint so the point lands on sailable water.
function Port:dockPoint()
    if self.dockX then return self.dockX, self.dockY end   -- set by terrain (shoreline water)
    local d = Port.FOOTPRINT * config.TILE * 0.5 + 40       -- fallback
    return self.x + self.seaDx * d, self.y + self.seaDy * d
end

function Port:isBoatInRange(boat)
    local dpx, dpy = self:dockPoint()
    local dx, dy = boat.x - dpx, boat.y - dpy
    return (dx * dx + dy * dy) <= (config.PICKUP_RADIUS * config.PICKUP_RADIUS)
end

function Port:toObject()
    return {
        tx = self.tx, ty = self.ty, w = self.w, h = self.h, z = self.buildZ,
        sprite = "ports/" .. self.id .. ".png",
        data = self,
        draw = function(_, g) self:drawPlaceholder(g) end,
    }
end

function Port:drawPlaceholder(g)
    local c   = config.colors
    local z   = g.z
    local sdx, sdy = self.seaDx, self.seaDy        -- toward the sea
    local px, py   = -sdy, sdx                      -- along the shore
    local salt = #self.id

    -- helpers (capture coords into locals: pos() returns two values, which Lua
    -- would otherwise truncate when used mid-argument-list)
    local function gxof(s, p) return g.cx + sdx * s + px * p end
    local function gyof(s, p) return g.cy + sdy * s + py * p end
    local function box(s, p, hw, hd, z0, z1, color)
        Objects.box(gxof(s, p), gyof(s, p), hw, hd, z0, z1, color)
    end
    local function building(s, p, hw, hd, wallH, roofH, wall, roof)
        Objects.building(gxof(s, p), gyof(s, p), hw, hd, z, wallH, roofH, wall, roof)
    end
    local bc = config.BUILDING_COLORS
    local function col(n) return bc[((salt + n) % #bc) + 1] end

    -- 1) lot + a darker quay/apron near the water
    Objects.drawLot(g, c.lot)
    box(36, 0, 56, 30, z, z + 1.5, c.road)

    -- 2) main warehouse with windows + a pitched roof
    building(-44, -16, 34, 28, 40, 20, c.building_wall, self.color)

    -- 3) a cluster of varied town buildings (different sizes/heights/roofs)
    building(-58, 38,  16, 16, 22, 16, c.building_wall, col(1))   -- house
    building(-30, 56,  14, 14, 18, 14, c.building_wall, col(2))   -- house
    building(-78, 2,   18, 18, 54, 18, c.building_dk,   col(3))   -- tall office
    building(-20, -54, 20, 14, 26, 12, c.building_wall, col(4))   -- shed

    -- 4) two storage tanks
    box(2,  -52, 9, 9, z, z + 22, c.stone)
    box(22, -48, 9, 9, z, z + 22, c.stone)

    -- 5) a lighthouse near the seaward corner, with a blinking lamp
    box(46, -44, 8,   8,   z,      z + 56, c.building_wall)
    box(46, -44, 8.5, 8.5, z + 30, z + 38, {0.70, 0.30, 0.26})  -- red band
    local lsx, lsy = Iso.project(gxof(46, -44), gyof(46, -44), z + 64)
    love.graphics.setColor((math.sin(self.bob * 2.0) > 0) and {1.0, 0.92, 0.5} or {0.7, 0.6, 0.3})
    love.graphics.circle("fill", lsx, lsy, 5)

    -- 6) a crane near the quay
    self:drawCrane(gxof(18, 44), gyof(18, 44), z)

    -- 7) crates
    box(28, 12, 7, 7, z, z + 14, col(5))
    box(40, 24, 6, 6, z, z + 11, col(2))

    -- 8) stone breakwater curving out into the sea (protects the harbor)
    for k = 1, 7 do
        local s = 70 + k * 22
        local p = 62 + k * k * 1.6              -- gentle curve
        box(s, p, 11, 11, 0, 9, c.stone)
    end

    -- 9) docked ships of different types along the quay (on the water)
    local shipAngle = math.atan2(py, px)
    for idx = -1, 1 do
        local sc = config.SHIP_COLORS[((idx + salt + 1) % #config.SHIP_COLORS) + 1]
        Objects.drawShip(gxof(64, idx * 40), gyof(64, idx * 40), shipAngle, sc,
            (idx == 0) and 1.15 or 0.9, 0)
    end

    self:drawLabel(g)
    love.graphics.setColor(1, 1, 1)
end

function Port:drawCrane(gx, gy, z)
    local bx, by = Iso.project(gx, gy, z)
    local tx, ty = Iso.project(gx, gy, z + 64)
    love.graphics.setColor(0.85, 0.65, 0.2)
    love.graphics.setLineWidth(4)
    love.graphics.line(bx, by, tx, ty)                       -- mast
    love.graphics.setLineWidth(3)
    love.graphics.line(tx, ty, tx + 34, ty + 6)              -- jib arm
    love.graphics.setColor(0.2, 0.2, 0.22)
    love.graphics.setLineWidth(1)
    love.graphics.line(tx + 30, ty + 5, tx + 30, ty + 22)    -- cable
    love.graphics.rectangle("fill", tx + 26, ty + 22, 8, 6)  -- hook block
end

function Port:drawLabel(g)
    local font = love.graphics.getFont()
    local sx, sy = Iso.project(g.cx, g.cy, g.z + 96)
    local w = font:getWidth(self.name)
    local hh = font:getHeight()
    local c = config.colors
    love.graphics.setColor(c.panel[1], c.panel[2], c.panel[3], 0.82)
    love.graphics.rectangle("fill", sx - w / 2 - 6, sy - hh / 2 - 2, w + 12, hh + 4, 4, 4)
    love.graphics.setColor(c.text)
    love.graphics.print(self.name, sx - w / 2, sy - hh / 2)
end

return Port
