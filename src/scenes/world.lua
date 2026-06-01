-- src/scenes/world.lua
-- The playable scene: an isometric ocean world with islands, ports, the boat,
-- the cargo economy, the follow camera, and the HUD.
--
-- Core loop: sail (arrows or click) -> MELLOMROM at a port to load/deliver -> gold.
--
-- Rendering note: terrain tiles AND entities are drawn in a single
-- back-to-front pass sorted by isometric depth, so the boat correctly slips
-- behind or in front of raised land. Movement/collision all happen in the
-- flat ground plane; only drawing knows about isometric projection.

local config       = require("src.config")
local Assets       = require("src.assets")
local Iso          = require("src.systems.iso")
local Camera       = require("src.systems.camera")
local Terrain      = require("src.systems.terrain")
local Objects      = require("src.systems.objects")
local CargoSystem  = require("src.systems.cargo")
local Boat         = require("src.entities.boat")
local Port         = require("src.entities.port")
local HUD          = require("src.ui.hud")

local World = {}

function World:load(game)
    self.game    = game
    self.camera  = Camera.new()
    self.panning = false
    self.toast   = { text = "", timer = 0, rise = 0 }

    -- Ports (data-driven). Created first so the terrain can snap them to coasts.
    self.ports = {}
    for _, def in ipairs(game.data.ports) do
        self.ports[#self.ports + 1] = Port.new(def)
    end

    -- Build the procedurally heightmapped iso world (and place the ports).
    self.terrain = Terrain.new(self.ports)

    -- Boat: the player's "best" unlocked boat, started on open water.
    local unlocked = game.state.unlockedBoats
    local boatDef  = game:getBoatDef(unlocked[#unlocked])
    local sx, sy   = self:findStartWater(config.WORLD_WIDTH / 2, config.WORLD_HEIGHT / 2)
    self.boat = Boat.new(boatDef, sx, sy)

    -- Sprite-object layer: ports (3x3), props (1x1), ambient ships.
    self.objects = Objects.new()
    for _, port in ipairs(self.ports) do
        self.objects:add(port:toObject())
    end
    for _, p in ipairs(self.terrain.props) do
        if p.kind == "forest" then
            self.objects:add({
                tx = p.tx, ty = p.ty, z = p.z,
                draw = function(_, g) Objects.drawForest(g, p.salt) end,
            })
        elseif p.kind == "house" then
            self.objects:add({
                tx = p.tx, ty = p.ty, z = p.z,
                sprite = "props/house.png",
                draw = function(_, g)  -- fallback if the PNG is missing
                    Objects.building(g.cx, g.cy, 16, 16, g.z, 22, 14,
                        config.colors.building_wall, config.colors.building_dk)
                end,
            })
        else
            self.objects:add({
                tx = p.tx, ty = p.ty, z = p.z,
                sprite = "props/" .. p.kind .. ".png",
                draw = function(_, g) Objects.drawRock(g) end,
            })
        end
    end
    self:spawnAmbientShips()

    self.cargoSystem = CargoSystem.new(self.ports)

    self.camera:snapTo(self.boat.x, self.boat.y)
    self.nearPort = nil
    self.items = {}  -- reused render list (sorted each frame)
end

-- Find a nearby water tile to start the boat on (spirals out from a guess).
function World:findStartWater(gx, gy)
    local T = config.TILE
    for r = 0, 40 do
        for a = 0, math.max(1, r * 6) do
            local ang = (a / math.max(1, r * 6)) * math.pi * 2
            local x = gx + math.cos(ang) * r * T
            local y = gy + math.sin(ang) * r * T
            if x > 0 and y > 0 and x < config.WORLD_WIDTH and y < config.WORLD_HEIGHT
               and self.terrain:isWater(x, y) then
                return x, y
            end
        end
    end
    return gx, gy
end

-- A couple of ambient ships bobbing in the sea just outside each harbor.
function World:spawnAmbientShips()
    local T = config.TILE
    for si, port in ipairs(self.ports) do
        local gx = port.x + port.seaDx * 260
        local gy = port.y + port.seaDy * 260
        if self.terrain:isWater(gx, gy) then
            local col = config.SHIP_COLORS[((si) % #config.SHIP_COLORS) + 1]
            local ang = math.atan2(-port.seaDx, port.seaDy)
            local phase = si * 1.3
            self.objects:add({
                tx = math.floor(gx / T) + 1, ty = math.floor(gy / T) + 1, z = 0,
                draw = function(_, g)
                    local bob = math.sin(love.timer.getTime() * 1.2 + phase) * 2
                    Objects.drawShip(g.cx, g.cy, ang, col, 1.0, bob)
                end,
            })
        end
    end
end

function World:update(dt)
    self.terrain:update(dt)
    self.boat:update(dt)
    self.boat:blockLand(self.terrain)   -- keep the boat on the water

    for _, port in ipairs(self.ports) do port:update(dt) end

    self:checkIslandDiscovery()

    self.nearPort = nil
    for _, port in ipairs(self.ports) do
        if port:isBoatInRange(self.boat) then self.nearPort = port; break end
    end

    self.camera:edgeScroll(dt)   -- push mouse to screen edge to scroll
    self.camera:update(dt)

    if self.toast.timer > 0 then
        self.toast.timer = self.toast.timer - dt
        self.toast.rise  = self.toast.rise + dt * 30
    end
end

function World:checkIslandDiscovery()
    for _, isl in ipairs(self.terrain.islandCenters) do
        local dx, dy = self.boat.x - isl.x, self.boat.y - isl.y
        if (dx * dx + dy * dy) < (520 ^ 2) and not self:isDiscovered(isl.id) then
            table.insert(self.game.state.discoveredIslands, isl.id)
            self.game:save()
            self:showToast("Ny øy oppdaget!")
            Assets.playSfx("deliver")
        end
    end
end

function World:isDiscovered(id)
    for _, d in ipairs(self.game.state.discoveredIslands) do
        if d == id then return true end
    end
    return false
end

-- Load + deliver in a single press: deliver anything bound here, then top up.
function World:interact()
    if not self.nearPort then return end
    local port = self.nearPort
    local earned, delivered = self.cargoSystem:tryDeliver(self.boat, port)

    local offer
    if self.boat:hasRoom() then
        offer = self.cargoSystem:tryPickup(self.boat, port)
    end

    if delivered > 0 then
        self.game:addCoins(earned)
        self:showToast("+" .. earned .. " gull!")
        Assets.playSfx("deliver")
    elseif offer then
        self:showToast("Lastet " .. offer.type .. "!")
        Assets.playSfx("horn")
    end
end

function World:showToast(text)
    self.toast.text, self.toast.timer, self.toast.rise = text, 2.0, 0
end

-- ── Drawing ────────────────────────────────────────────────────────────────
function World:draw()
    love.graphics.clear(config.colors.water_deep)

    self.camera:attach()
    self:drawWorldSorted()
    self.camera:detach()

    HUD.draw(self)
end

local function byDepth(a, b)
    if a.depth == b.depth then return a.seq < b.seq end
    return a.depth < b.depth
end

-- Two passes:
--   1) ALL ground tiles (sorted) — the ground is flat, so it never needs to
--      occlude anything floating on it. Drawing it first means ocean tiles can
--      no longer clip over the boat.
--   2) Objects (ports/trees/rocks) + the boat + the destination marker, sorted
--      among themselves so buildings/trees still overlap the boat correctly.
function World:drawWorldSorted()
    local minGx, minGy, maxGx, maxGy = self.camera:groundBounds()
    local i0, j0, i1, j1 = self.terrain:visibleRange(minGx, minGy, maxGx, maxGy)

    -- Pass 1: ground tiles
    local tiles = self.items
    for k = #tiles, 1, -1 do tiles[k] = nil end
    for i = i0, i1 do
        for j = j0, j1 do
            tiles[#tiles + 1] = { depth = self.terrain:tileDepth(i, j), i = i, j = j }
        end
    end
    for k = 1, #tiles do tiles[k].seq = k end
    table.sort(tiles, byDepth)
    for _, t in ipairs(tiles) do self.terrain:drawTile(t.i, t.j) end

    -- Pass 2: things that sit on the ground
    local objs = {}
    if self.boat.destX then
        objs[#objs + 1] = { depth = Iso.depth(self.boat.destX, self.boat.destY), kind = "dest" }
    end
    self.objects:collectVisible(i0, j0, i1, j1, function(depth, obj)
        objs[#objs + 1] = { depth = depth, kind = "object", obj = obj }
    end)
    objs[#objs + 1] = { depth = Iso.depth(self.boat.x, self.boat.y), kind = "boat" }
    for k = 1, #objs do objs[k].seq = k end
    table.sort(objs, byDepth)
    for _, it in ipairs(objs) do
        if it.kind == "object" then Objects.draw(it.obj)
        elseif it.kind == "boat" then self.boat:draw()
        elseif it.kind == "dest" then self:drawDestinationMarker() end
    end
    love.graphics.setColor(1, 1, 1)
end

function World:drawDestinationMarker()
    local c = config.colors
    local sx, sy = Iso.project(self.boat.destX, self.boat.destY, 0)
    local pulse = 8 + math.sin(love.timer.getTime() * 6) * 3
    love.graphics.setColor(c.gold[1], c.gold[2], c.gold[3], 0.85)
    love.graphics.setLineWidth(3)
    love.graphics.ellipse("line", sx, sy, pulse + 8, (pulse + 8) * 0.5)
    love.graphics.setLineWidth(1)
end

-- ── Input ────────────────────────────────────────────────────────────────
function World:keypressed(key)
    if key == "space" then
        self:interact()
    elseif key == "c" then
        self.camera:centerOn(self.boat.x, self.boat.y)  -- recenter on the boat
    end
end

function World:mousepressed(x, y, button)
    if button == 1 then
        local wx, wy = self.camera:screenToWorld(x, y)
        self.boat:setDestination(wx, wy)
    elseif button == 2 then
        self.panning = true
    end
end

function World:mousereleased(x, y, button)
    if button == 2 then
        self.panning = false
    end
end

function World:mousemoved(x, y, dx, dy)
    if self.panning then self.camera:drag(dx, dy) end
end

function World:wheelmoved(dx, dy)
    self.camera:zoomBy(dy * 0.1)
end

return World
