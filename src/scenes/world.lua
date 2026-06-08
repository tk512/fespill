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
local Fog          = require("src.systems.fog")
local Boat         = require("src.entities.boat")
local Port         = require("src.entities.port")
local HUD          = require("src.ui.hud")
local PortScreen   = require("src.ui.portscreen")

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
        self.objects:add(port:toDockObject())   -- the pier, as its own object
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
    -- Cities: scatter buildings around each port to show how big the town is.
    for _, port in ipairs(self.ports) do
        self:scatterCity(port)
    end

    self:spawnAmbientShips()

    self.cargoSystem = CargoSystem.new(self.ports)

    -- Fog of war: restore explored area from the save, then light up where the
    -- boat already is so the starting patch is visible.
    self.fog = Fog.new(game.state.fog)
    self.fog:revealAround(self.boat.x, self.boat.y, config.FOG_REVEAL)
    self._fogSaveT = 0

    self.camera:snapTo(self.boat.x, self.boat.y)
    self.nearPort = nil
    self.dock = nil          -- the docking screen overlay, when open
    self.dockSuppress = nil  -- port id we just left a dock for (don't re-pop)
    self.items = {}  -- reused render list (sorted each frame)

    collectgarbage("collect")
end

-- Scatter houses around a port's pad to make it read as a town. Count + spread
-- come from the port's `size` (config.CITY_SIZES). Houses only land on dry,
-- non-pad tiles, nearest-first, so they cluster around the harbour.
function World:scatterCity(port)
    local spec = config.CITY_SIZES[port.def.size or "small"] or config.CITY_SIZES.small
    local T = config.TILE
    local ti, tj, R = port.tx, port.ty, spec.spread
    local cands = {}
    for di = -R, R do
        for dj = -R, R do
            local i, j = ti + di, tj + dj
            if i >= 1 and j >= 1 and i <= self.terrain.nx and j <= self.terrain.ny then
                local pad = self.terrain.buildMask[i] and self.terrain.buildMask[i][j]
                local gx, gy = (i - 0.5) * T, (j - 0.5) * T
                if not pad and not self.terrain:isWater(gx, gy) then
                    cands[#cands + 1] = { i = i, j = j, d = di * di + dj * dj }
                end
            end
        end
    end
    table.sort(cands, function(a, b) return a.d < b.d end)
    for k = 1, math.min(spec.houses, #cands) do
        local c = cands[k]
        self.objects:add({
            tx = c.i, ty = c.j, z = 0, sprite = "props/house.png",
            draw = function(_, g)
                Objects.building(g.cx, g.cy, 16, 16, g.z, 22, 14,
                    config.colors.building_wall, config.colors.building_dk)
            end,
        })
    end
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
    -- While the docking screen is up, the world is frozen.
    if self.dock then self.dock:update(dt); return end

    self.terrain:update(dt)
    self.boat:update(dt)
    self.boat:blockLand(self.terrain)   -- keep the boat on the water

    for _, port in ipairs(self.ports) do port:update(dt) end

    -- Reveal fog around the boat; persist new discoveries (throttled to disk).
    if self.fog:revealAround(self.boat.x, self.boat.y, config.FOG_REVEAL) then
        self.game.state.fog = self.fog:serialize()
        self._fogDirty = true
    end
    self._fogSaveT = self._fogSaveT + dt
    if self._fogDirty and self._fogSaveT > 8 then   -- write to disk rarely (avoids hitches)
        self.game:save(); self._fogDirty = false; self._fogSaveT = 0
    end

    self:checkIslandDiscovery()

    self.nearPort = nil
    for _, port in ipairs(self.ports) do
        if port:isBoatInRange(self.boat) then self.nearPort = port; break end
    end

    -- Docking with a "latch": when the boat gets close it is gently pulled into
    -- the berth beside the pier, and only THEN does the screen open — so it
    -- parks neatly instead of unloading out at sea / under the harbour.
    if self.latching then
        local bx, by = self.latching:berth()
        local dx, dy = bx - self.boat.x, by - self.boat.y
        self.boat:setDestination(bx, by)            -- keep pulling it in
        self._latchT = (self._latchT or 0) + dt
        if (dx * dx + dy * dy) < (20 * 20) or self._latchT > 2.5 then
            local p = self.latching
            self.latching, self._latchT = nil, 0
            self:openDock(p)
            return
        end
    elseif self.nearPort then
        if self.nearPort.id ~= self.dockSuppress then
            self.latching = self.nearPort           -- start the glide-in
            self._latchT = 0
        end
    else
        self.dockSuppress = nil  -- left all ports; allow docking again
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
        local reach = (isl.radius or 520) + 200   -- "discovered" on reaching its coast
        if (dx * dx + dy * dy) < (reach * reach) and not self:isDiscovered(isl.id) then
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

-- Dock at a port and pop the docking screen. Decides what the screen shows:
--   deliver  — we're carrying passengers/goods bound for this town (gold!)
--   offer    — this town has a job and the boat has room
--   visit    — nothing to do right now (friendly hello)
function World:openDock(port)
    self.boat:clearDestination()   -- stop nudging while we're parked

    local earned, delivered = self.cargoSystem:tryDeliver(self.boat, port)
    local mode, offer
    if delivered > 0 then
        self.game:addCoins(earned)
        Assets.playSfx("deliver")
        mode = "deliver"
    elseif self.boat:cargoCount() > 0 then
        mode = "busy"                       -- already on a mission for another town
    else
        offer = self.cargoSystem:offerAt(port.id)
        mode = (offer and self.boat:hasRoom()) and "offer" or "visit"
    end

    self.dock = PortScreen.new(self, port, {
        mode = mode, offer = offer, earned = earned, delivered = delivered,
        mission = self.boat.cargo[1],       -- so "busy" can name where to go
    })
    self.dockSuppress = port.id    -- don't immediately re-pop while still in range
end

function World:showToast(text)
    self.toast.text, self.toast.timer, self.toast.rise = text, 2.0, 0
end

-- ── Drawing ────────────────────────────────────────────────────────────────
function World:draw()
    love.graphics.clear(config.colors.water_deep)

    self.camera:attach()
    self:drawWorldSorted()
    self:drawFog()                 -- dark over everything not yet explored
    self.camera:detach()

    HUD.draw(self)

    if not self.dock then self:drawMissionPointer() end  -- "go this way!" hint
    if self.dock then self.dock:draw() end   -- docking modal on top of everything
end

function World:portById(id)
    for _, p in ipairs(self.ports) do
        if p.id == id then return p end
    end
end

-- While on a mission, draw a big bouncing arrow above the boat pointing toward
-- the destination town, plus a pulsing ring on that town — so a non-reader
-- always knows where to go next.
function World:drawMissionPointer()
    local m = self.boat.cargo[1]
    if not m then return end
    local port = self:portById(m.toId)
    if not port then return end

    local bx, by = self.camera:worldToScreen(self.boat.x, self.boat.y)
    local tx, ty = self.camera:worldToScreen(port.x, port.y)
    local ang = math.atan2(ty - by, tx - bx)
    local t = love.timer.getTime()

    -- pulsing ring on the target town (if it's on screen)
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    if tx > 0 and tx < sw and ty > 0 and ty < sh then
        local pr = 26 + math.sin(t * 4) * 6
        love.graphics.setColor(m.color[1], m.color[2], m.color[3], 0.9)
        love.graphics.setLineWidth(4)
        love.graphics.circle("line", tx, ty, pr)
        love.graphics.setLineWidth(1)
    end

    -- the pointing arrow, hovering just above the boat, bobbing toward target
    local hx, hy = bx, by - 70 + math.sin(t * 3) * 6
    local s = 1 + 0.08 * math.sin(t * 5)
    love.graphics.push()
    love.graphics.translate(hx, hy)
    love.graphics.rotate(ang)
    love.graphics.scale(s, s)
    local arrow = { -22, -8, 6, -8, 6, -18, 34, 0, 6, 18, 6, 8, -22, 8 }
    love.graphics.setColor(0.10, 0.08, 0.05, 0.9)        -- dark outline
    love.graphics.setLineWidth(6)
    love.graphics.polygon("line", arrow)
    love.graphics.setColor(0.98, 0.82, 0.25)             -- bright gold
    love.graphics.polygon("fill", arrow)
    love.graphics.setLineWidth(1)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

-- Cover every visible, not-yet-explored tile with a dark "unknown" diamond.
-- Drawn in world space on top of the terrain + objects, so unexplored islands,
-- cities and props stay hidden until the boat sails close.
function World:drawFog()
    local T = config.TILE
    local minGx, minGy, maxGx, maxGy = self.camera:groundBounds()
    local i0, j0, i1, j1 = self.terrain:visibleRange(minGx, minGy, maxGx, maxGy)
    love.graphics.setColor(0.03, 0.05, 0.09, 1)
    for i = i0, i1 do
        for j = j0, j1 do
            if not self.fog:pointRevealed((i - 0.5) * T, (j - 0.5) * T) then
                local ax, ay = Iso.project((i - 1) * T, (j - 1) * T, 0)
                local bx, by = Iso.project(i * T,       (j - 1) * T, 0)
                local cx, cy = Iso.project(i * T,       j * T,       0)
                local dx, dy = Iso.project((i - 1) * T, j * T,       0)
                love.graphics.polygon("fill", ax, ay, bx, by, cx, cy, dx, dy)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
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

    -- Pass 1: ground tiles. Entries are POOLED (reused frame to frame) so we
    -- don't allocate one table per visible tile every frame (that garbage was
    -- causing periodic GC pauses / framerate dips).
    local tiles = self.items
    local tpool = self._tilePool
    if not tpool then tpool = {}; self._tilePool = tpool end
    local nt = 0
    for i = i0, i1 do
        for j = j0, j1 do
            nt = nt + 1
            local e = tpool[nt]; if not e then e = {}; tpool[nt] = e end
            e.depth = self.terrain:tileDepth(i, j); e.i = i; e.j = j; e.seq = nt
            tiles[nt] = e
        end
    end
    for k = #tiles, nt + 1, -1 do tiles[k] = nil end
    table.sort(tiles, byDepth)
    for k = 1, nt do local t = tiles[k]; self.terrain:drawTile(t.i, t.j) end

    -- Baked jagged shoreline (one draw call) on top of the flat water bases.
    if self.terrain.coastMesh then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.terrain.coastMesh)
    end

    -- Pass 2: things that sit on the ground (also pooled — no per-frame garbage).
    local vis = self._vis
    if not vis then vis = {}; self._vis = vis end
    for k = #vis, 1, -1 do vis[k] = nil end
    self.objects:collectVisible(i0, j0, i1, j1, vis)

    local objs = self._objs
    if not objs then objs = {}; self._objs = objs end
    local opool = self._objPool
    if not opool then opool = {}; self._objPool = opool end
    local no = 0
    local function entry(depth, kind, obj)
        no = no + 1
        local e = opool[no]; if not e then e = {}; opool[no] = e end
        e.depth = depth; e.kind = kind; e.obj = obj; e.seq = no
        objs[no] = e
    end
    if self.boat.destX then entry(Iso.depth(self.boat.destX, self.boat.destY), "dest", nil) end
    for vi = 1, #vis do entry(vis[vi].depth, "object", vis[vi]) end
    entry(Iso.depth(self.boat.x, self.boat.y), "boat", nil)
    for k = #objs, no + 1, -1 do objs[k] = nil end
    table.sort(objs, byDepth)
    for k = 1, no do
        local it = objs[k]
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
-- While docked, all input goes to the docking screen.
function World:keypressed(key)
    if self.dock then self.dock:keypressed(key); return end
    -- Docking is fully automatic (sail up to a port and the screen pops up), so
    -- there's no "press a key to load" — that just confused a non-reader.
    if key == "c" then
        self.camera:centerOn(self.boat.x, self.boat.y)  -- recenter on the boat
    end
end

function World:mousepressed(x, y, button)
    if self.dock then self.dock:mousepressed(x, y, button); return end
    if button == 1 then
        if self.latching then return end   -- being pulled into the berth; ignore clicks
        local wx, wy = self.camera:screenToWorld(x, y)
        self.boat:setDestination(wx, wy)
    elseif button == 2 then
        self.panning = true
    end
end

function World:mousereleased(x, y, button)
    if self.dock then return end
    if button == 2 then
        self.panning = false
    end
end

function World:mousemoved(x, y, dx, dy)
    if self.dock then return end
    if self.panning then self.camera:drag(dx, dy) end
end

-- Mouse wheel is intentionally IGNORED: the kid kept zooming all the way out.
-- The view stays at a fixed, comfortable zoom (config.CAMERA_DEFAULT_ZOOM);
-- explore by sailing / pushing the mouse to the screen edge.
function World:wheelmoved(dx, dy)
end

return World
