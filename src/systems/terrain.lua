-- src/systems/terrain.lua
-- FLAT isometric tilemap (sprite-first). Per the chosen art direction we drop
-- terrain elevation: the ground is a flat 2:1 iso tile map of water / sand /
-- grass / rock, with curvy (marching-squares) coastlines. Every tile draws its
-- PNG from assets/tiles/<type>.png when present, and falls back to textured
-- code art when it isn't — so a CC0 pixel tileset drops straight in.
--
-- Generation is still procedural (island masks + noise) so coastlines are
-- irregular and natural. Heights are gone, so heightAt() is always 0.

local config = require("src.config")
local Iso    = require("src.systems.iso")
local Assets = require("src.assets")

local Terrain = {}
Terrain.__index = Terrain

-- ── deterministic value noise (stable per seed) ────────────────────────────
local function hashf(x, y, seed)
    local s = math.sin(x * 12.9898 + y * 78.233 + seed * 0.1357) * 43758.5453
    return s - math.floor(s)
end
local function smooth(t) return t * t * (3 - 2 * t) end
local function valueNoise(x, y, seed)
    local x0, y0 = math.floor(x), math.floor(y)
    local fx, fy = smooth(x - x0), smooth(y - y0)
    local a = hashf(x0, y0, seed);     local b = hashf(x0 + 1, y0, seed)
    local c = hashf(x0, y0 + 1, seed); local d = hashf(x0 + 1, y0 + 1, seed)
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy
end
local function fbm(x, y, seed)
    local v, amp, freq, norm = 0, 1, 1, 0
    for _ = 1, 4 do
        v = v + valueNoise(x * freq, y * freq, seed) * amp
        norm = norm + amp; amp = amp * 0.5; freq = freq * 2
    end
    return v / norm
end

-- ── construction ────────────────────────────────────────────────────────────
function Terrain.new(ports)
    local self = setmetatable({}, Terrain)
    local T = config.TILE
    self.nx = math.ceil(config.WORLD_WIDTH  / T)
    self.ny = math.ceil(config.WORLD_HEIGHT / T)
    self.time = 0
    self.props = {}
    self.islandCenters = {}

    self:generateLand()          -- corner land/water flags (irregular coasts)
    self:snapPorts(ports)        -- place ports on the coast + mark their pads
    self:classifyTiles()         -- water / sand / grass / rock per tile
    self:scatterProps()
    self:buildCoastMesh()        -- bake the jagged shoreline into one static mesh

    for i, isl in ipairs(config.ISLANDS) do
        self.islandCenters[i] = { x = isl.x, y = isl.y, radius = isl.radius, id = "island" .. i }
    end
    return self
end

-- Corner grid: 1 = land, 0 = sea. Island masks set the broad shape; noise
-- perturbs the edge so coastlines are irregular rather than circular.
function Terrain:generateLand()
    local T = config.TILE
    local seed = config.WORLD_SEED
    self.corner = {}
    for ci = 1, self.nx + 1 do
        self.corner[ci] = {}
        local gx = (ci - 1) * T
        for cj = 1, self.ny + 1 do
            local gy = (cj - 1) * T
            local mask = 0
            for _, isl in ipairs(config.ISLANDS) do
                local dx, dy = gx - isl.x, gy - isl.y
                local d = math.sqrt(dx * dx + dy * dy) / isl.radius
                if d < 1 then mask = math.max(mask, smooth(1 - d)) end
            end
            local edge = (fbm(gx / config.COAST_SCALE, gy / config.COAST_SCALE, seed) - 0.5) * 2
            self.corner[ci][cj] = (mask + edge * config.COAST_NOISE > config.LAND_THRESH) and 1 or 0
        end
    end
end

local function cornersAllZero(self, i, j)
    return self.corner[i][j] == 0 and self.corner[i + 1][j] == 0
       and self.corner[i + 1][j + 1] == 0 and self.corner[i][j + 1] == 0
end

-- Place each port on the nearest coastal land tile + record the build pad.
function Terrain:snapPorts(ports)
    local T = config.TILE
    self.buildMask = {}
    local function isLand(i, j) return not cornersAllZero(self, i, j) end
    local function isWaterT(i, j) return cornersAllZero(self, i, j) end

    for _, port in ipairs(ports) do
        local startI = math.max(2, math.min(self.nx - 5, math.floor(port.x / T)))
        local startJ = math.max(2, math.min(self.ny - 5, math.floor(port.y / T)))
        local best, bestD
        for r = 0, 60 do   -- wide search: islands are large, ports start inland
            for di = -r, r do
                for dj = -r, r do
                    if math.abs(di) == r or math.abs(dj) == r then
                        local i, j = startI + di, startJ + dj
                        if i >= 2 and j >= 2 and i <= self.nx - 4 and j <= self.ny - 4 and isLand(i, j) then
                            if isWaterT(i + 1, j) or isWaterT(i - 1, j)
                               or isWaterT(i, j + 1) or isWaterT(i, j - 1) then
                                local d = di * di + dj * dj
                                if not bestD or d < bestD then bestD, best = d, { i, j } end
                            end
                        end
                    end
                end
            end
            if best then break end
        end
        best = best or { startI, startJ }

        local w, h = port.w, port.h
        local i0 = math.min(math.max(1, best[1] - 1), self.nx - w)
        local j0 = math.min(math.max(1, best[2] - 1), self.ny - h)

        -- force the footprint to solid land + flag it (flat, no props)
        for ci = i0, i0 + w do for cj = j0, j0 + h do self.corner[ci][cj] = 1 end end
        for i = i0, i0 + w - 1 do
            self.buildMask[i] = self.buildMask[i] or {}
            for j = j0, j0 + h - 1 do self.buildMask[i][j] = true end
        end

        local cx = (i0 - 1 + w / 2) * T
        local cy = (j0 - 1 + h / 2) * T
        local function waterAt(gx, gy)
            local ti = math.max(1, math.min(self.nx, math.floor(gx / T) + 1))
            local tj = math.max(1, math.min(self.ny, math.floor(gy / T) + 1))
            return cornersAllZero(self, ti, tj)
        end
        local sdx, sdy = 0, 0
        for _, dir in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            if waterAt(cx + dir[1] * T * (w + 1), cy + dir[2] * T * (h + 1)) then
                sdx, sdy = sdx + dir[1], sdy + dir[2]
            end
        end
        if sdx == 0 and sdy == 0 then sdy = 1 end
        local mag = math.sqrt(sdx * sdx + sdy * sdy)
        local ux, uy = sdx / mag, sdy / mag
        port:placeAt(i0, j0, cx, cy, 0, ux, uy)  -- buildZ = 0 (flat)

        -- Dock point: step out from the harbour centre along the sea direction
        -- to the FIRST water tile (then a touch further), so the boat has a real
        -- spot in the water to pull up to. Stored on the port for isBoatInRange.
        local dockX, dockY = cx + ux * T, cy + uy * T
        for s = 1, 40 do
            local gx, gy = cx + ux * T * 0.5 * s, cy + uy * T * 0.5 * s
            if waterAt(gx, gy) then
                dockX, dockY = gx + ux * T * 0.6, gy + uy * T * 0.6
                break
            end
        end
        port.dockX, port.dockY = dockX, dockY
    end
end

-- Classify each tile from its corner land flags + a land-cover noise.
function Terrain:classifyTiles()
    local T = config.TILE
    local seed = config.WORLD_SEED
    self.tiles = {}
    for i = 1, self.nx do
        self.tiles[i] = {}
        for j = 1, self.ny do
            local land = self.corner[i][j] + self.corner[i + 1][j]
                       + self.corner[i + 1][j + 1] + self.corner[i][j + 1]
            local build = self.buildMask and self.buildMask[i] and self.buildMask[i][j]
            local tile = { land = land, build = build or false }

            if land == 0 then
                tile.type, tile.water = "water", true
            elseif land < 4 then
                tile.type, tile.water = "sand", false   -- coastline (curvy beach)
            else
                local cx, cy = (i - 0.5) * T, (j - 0.5) * T
                local cover = fbm(cx / config.COVER_SCALE, cy / config.COVER_SCALE, seed + 11)
                tile.type, tile.water = (cover > config.ROCK_THRESH) and "rock" or "grass", false
            end
            if tile.build then tile.type, tile.water = "grass", false end
            tile.tint = 1 + (((i * 17 + j * 29) % 5) - 2) * 0.02
            self.tiles[i][j] = tile
        end
    end
    for i = 1, self.nx do
        for j = 1, self.ny do
            local t = self.tiles[i][j]
            if t.water then t.shallow = self:hasLandNeighbor(i, j) end
        end
    end
end

function Terrain:hasLandNeighbor(i, j)
    for di = -1, 1 do for dj = -1, 1 do
        local n = self.tiles[i + di] and self.tiles[i + di][j + dj]
        if n and not n.water then return true end
    end end
    return false
end

function Terrain:scatterProps()
    local T = config.TILE
    local seed = config.WORLD_SEED
    for i = 1, self.nx do
        for j = 1, self.ny do
            local t = self.tiles[i][j]
            if not t.water and not t.build then
                local cx, cy = (i - 0.5) * T, (j - 0.5) * T
                if t.type == "grass" then
                    local f = fbm(cx / config.FOREST_SCALE, cy / config.FOREST_SCALE, seed + 200)
                    if f > config.FOREST_THRESH then
                        self.props[#self.props + 1] = { tx = i, ty = j, kind = "forest", z = 0, salt = i * 131 + j * 977 }
                    elseif (i * 31 + j * 7) % 13 == 0 then
                        self.props[#self.props + 1] = { tx = i, ty = j, kind = "house", z = 0 }
                    end
                elseif t.type == "rock" and ((i * 53 + j * 97) % 7 == 0) then
                    self.props[#self.props + 1] = { tx = i, ty = j, kind = "rock", z = 0 }
                end
            end
        end
    end
end

-- ── queries (flat world: height is always 0) ───────────────────────────────
function Terrain:tileIndexAt(gx, gy)
    local T = config.TILE
    local i = math.max(1, math.min(self.nx, math.floor(gx / T) + 1))
    local j = math.max(1, math.min(self.ny, math.floor(gy / T) + 1))
    return i, j
end
function Terrain:isWater(gx, gy)
    local i, j = self:tileIndexAt(gx, gy)
    return self.tiles[i][j].water
end
function Terrain:heightAt() return 0 end
function Terrain:heightAtTile() return 0 end
function Terrain:update(dt) self.time = self.time + dt end

function Terrain:visibleRange(minGx, minGy, maxGx, maxGy)
    local T = config.TILE
    local i0 = math.max(1, math.floor(minGx / T) - 2)
    local j0 = math.max(1, math.floor(minGy / T) - 2)
    local i1 = math.min(self.nx, math.ceil(maxGx / T) + 2)
    local j1 = math.min(self.ny, math.ceil(maxGy / T) + 3)
    return i0, j0, i1, j1
end
function Terrain:tileDepth(i, j)
    local T = config.TILE
    return Iso.depth((i - 0.5) * T, (j - 0.5) * T)
end

-- ── drawing ─────────────────────────────────────────────────────────────────
-- Draw a tile PNG (flat, centred, fit to TILE). Returns false if not present.
function Terrain:drawSprite(ttype, i, j)
    local img = Assets.image("tiles/" .. ttype .. ".png")
    if not img then return false end
    local T = config.TILE
    local sx, sy = Iso.project((i - 0.5) * T, (j - 0.5) * T, 0)
    local scale = T / img:getWidth()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img, sx, sy, 0, scale, scale, img:getWidth() / 2, img:getHeight() / 2)
    return true
end

function Terrain:drawTile(i, j)
    local tile = self.tiles[i][j]
    if tile.water then
        if not self:drawSprite("water", i, j) then self:drawWater(i, j, tile) end
    elseif tile.land < 4 then
        -- coastal: draw only the water base here. The jagged pixel land edge is
        -- baked once into self.coastMesh (drawn in one call by the world), so we
        -- don't redraw hundreds of little polygons every frame.
        if not self:drawSprite("water", i, j) then self:drawWater(i, j, tile) end
    else
        if not self:drawSprite(tile.type, i, j) then self:drawLandFull(i, j, tile) end
    end
end

-- Bake the whole jagged, pixelized shoreline into ONE static mesh (built once at
-- load). Each coastal tile is split into COAST_PIXELS² sub-cells; land/wet-sand/
-- foam cells become little iso-diamond quads with baked colours. Land vs water
-- per sub-cell = bilinear of the 4 tile corners + world-space noise, so the coast
-- frays irregularly and joins seamlessly tile-to-tile. Drawing it is then a
-- single GPU call per frame instead of thousands of polygon() calls.
function Terrain:buildCoastMesh()
    local T = config.TILE
    local N = config.COAST_PIXELS
    local sub = T / N
    local jag = config.COAST_JAGGED
    local seed = config.WORLD_SEED
    local foam = config.colors.foam
    local v = {}

    local function quad(gx, gy, r, g, b, a)
        local x1, y1 = Iso.project(gx, gy, 0)
        local x2, y2 = Iso.project(gx + sub, gy, 0)
        local x3, y3 = Iso.project(gx + sub, gy + sub, 0)
        local x4, y4 = Iso.project(gx, gy + sub, 0)
        v[#v + 1] = { x1, y1, 0, 0, r, g, b, a }
        v[#v + 1] = { x2, y2, 0, 0, r, g, b, a }
        v[#v + 1] = { x3, y3, 0, 0, r, g, b, a }
        v[#v + 1] = { x1, y1, 0, 0, r, g, b, a }
        v[#v + 1] = { x3, y3, 0, 0, r, g, b, a }
        v[#v + 1] = { x4, y4, 0, 0, r, g, b, a }
    end

    for i = 1, self.nx do
        for j = 1, self.ny do
            local tile = self.tiles[i][j]
            if (not tile.water) and tile.land < 4 then
                local x0, y0 = (i - 1) * T, (j - 1) * T
                local lu = self.corner[i][j]
                local ru = self.corner[i + 1][j]
                local rd = self.corner[i + 1][j + 1]
                local ld = self.corner[i][j + 1]
                local fac = config.colors[tile.type] or config.colors.sand
                for a = 0, N - 1 do
                    for b = 0, N - 1 do
                        local u, vv = (a + 0.5) / N, (b + 0.5) / N
                        local top = lu + (ru - lu) * u
                        local bot = ld + (rd - ld) * u
                        local val = top + (bot - top) * vv
                        local gx, gy = x0 + (a + 0.5) * sub, y0 + (b + 0.5) * sub
                        val = val + (fbm(gx / 90, gy / 90, seed) - 0.5) * jag
                        if val > 0.5 then
                            if val < 0.58 then                  -- wet sand at the edge
                                quad(x0 + a * sub, y0 + b * sub, fac.lip[1], fac.lip[2], fac.lip[3], 1)
                            else
                                local tint = 0.9 + 0.2 * fbm(gx / 35, gy / 35, seed + 7)
                                quad(x0 + a * sub, y0 + b * sub,
                                    fac.top[1] * tint, fac.top[2] * tint, fac.top[3] * tint, 1)
                            end
                        elseif val > 0.43 then                  -- foam/surf off the beach
                            local aF = (val - 0.43) / 0.07
                            quad(x0 + a * sub, y0 + b * sub, foam[1], foam[2], foam[3], 0.55 * aF)
                        end
                    end
                end
            end
        end
    end

    if #v > 0 then
        self.coastMesh = love.graphics.newMesh(v, "triangles", "static")
    end
end

local function diamond(i, j)
    local T = config.TILE
    local x0, x1 = (i - 1) * T, i * T
    local y0, y1 = (j - 1) * T, j * T
    local ax, ay = Iso.project(x0, y0, 0)
    local bx, by = Iso.project(x1, y0, 0)
    local cx, cy = Iso.project(x1, y1, 0)
    local dx, dy = Iso.project(x0, y1, 0)
    return ax, ay, bx, by, cx, cy, dx, dy, x0, y0, x1, y1
end

function Terrain:drawWater(i, j, tile)
    local c = config.colors
    local ax, ay, bx, by, cx, cy, dx, dy, x0, y0 = diamond(i, j)
    love.graphics.setColor(tile.shallow and c.water_top or c.water_deep)
    love.graphics.polygon("fill", ax, ay, bx, by, cx, cy, dx, dy)
    local s = math.sin(self.time * 1.2 + (x0 + y0) * 0.010)
    if s > 0.65 then
        local mx, my = (ax + cx) / 2, (ay + cy) / 2
        love.graphics.setColor(c.wave[1], c.wave[2], c.wave[3], 0.07 * (s - 0.65))
        love.graphics.polygon("fill", mx, my - 5, mx + 12, my, mx, my + 5, mx - 12, my)
    end
end

function Terrain:drawLandFull(i, j, tile)
    local faces = config.colors[tile.type]
    local ax, ay, bx, by, cx, cy, dx, dy, x0, y0, x1, y1 = diamond(i, j)
    local tint = tile.tint or 1
    love.graphics.setColor(faces.top[1] * tint, faces.top[2] * tint, faces.top[3] * tint)
    love.graphics.polygon("fill", ax, ay, bx, by, cx, cy, dx, dy)
    self:drawTexture(x0, y0, x1, y1, tile.type, i * 131 + j * 977)
end

-- pixel-art texture inside a flat tile (deterministic)
function Terrain:drawTexture(x0, y0, x1, y1, ttype, seed)
    local c = config.colors[ttype]
    if not c then return end
    local s = seed % 2147483647
    local function rnd() s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 end
    local function spot()
        return Iso.project(x0 + (0.12 + rnd() * 0.76) * (x1 - x0),
                           y0 + (0.12 + rnd() * 0.76) * (y1 - y0), 0)
    end
    if ttype == "grass" then
        for _ = 1, 6 do
            local px, py = spot(); local f = rnd() < 0.5 and 0.80 or 1.16
            love.graphics.setColor(c.top[1] * f, c.top[2] * f, c.top[3] * f, 0.5)
            love.graphics.rectangle("fill", px, py, 2, 2)
        end
        love.graphics.setColor(c.lip[1], c.lip[2], c.lip[3], 0.55)
        for _ = 1, 4 do local px, py = spot(); love.graphics.rectangle("fill", px, py - 3, 1, 4) end
    elseif ttype == "sand" then
        for _ = 1, 7 do
            local px, py = spot(); local f = rnd() < 0.5 and 0.84 or 1.10
            love.graphics.setColor(c.top[1] * f, c.top[2] * f, c.top[3] * f, 0.5)
            love.graphics.rectangle("fill", px, py, 2, 2)
        end
    else
        for _ = 1, 6 do
            local px, py = spot(); local f = rnd() < 0.5 and 0.76 or 1.14
            love.graphics.setColor(c.top[1] * f, c.top[2] * f, c.top[3] * f, 0.55)
            love.graphics.rectangle("fill", px, py, rnd() < 0.3 and 3 or 2, 2)
        end
    end
end

return Terrain
