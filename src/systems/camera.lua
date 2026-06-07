-- src/systems/camera.lua
-- Isometric camera, classic mid-90s style: it does NOT chase the boat. You
-- scroll the map yourself by pushing the mouse to the screen edges (or
-- right-drag), and press C to recenter on your boat. No external libs.
--   * edgeScroll(dt) — pan when the cursor is near a screen edge
--   * drag(dx,dy)    — right-drag panning
--   * zoomBy(amount) — mouse wheel
--   * screenToWorld()/groundBounds() — click-to-move + tile culling

local config = require("src.config")
local Iso    = require("src.systems.iso")

local Camera = {}
Camera.__index = Camera

function Camera.new()
    local self = setmetatable({}, Camera)
    self.gx = config.WORLD_WIDTH  / 2   -- ground point shown at screen center
    self.gy = config.WORLD_HEIGHT / 2
    self.zoom = config.CAMERA_DEFAULT_ZOOM
    return self
end

function Camera:centerOn(gx, gy)
    self.gx, self.gy = gx, gy
    self:clamp()
end
Camera.snapTo = Camera.centerOn

function Camera:update(dt)
    self:clamp()
end

-- Keep the camera's center inside the world.
function Camera:clamp()
    self.gx = math.max(0, math.min(config.WORLD_WIDTH,  self.gx))
    self.gy = math.max(0, math.min(config.WORLD_HEIGHT, self.gy))
end

-- Move the view by a screen-space delta (in pixels). Used by edge-scroll and
-- (negated) by drag. Converting through the iso inverse keeps panning aligned
-- with what you see.
function Camera:panScreen(sx, sy)
    local gdx, gdy = Iso.unproject(sx / self.zoom, sy / self.zoom)
    self.gx = self.gx + gdx
    self.gy = self.gy + gdy
    self:clamp()
end

-- Scroll when the cursor is within EDGE pixels of a screen border.
function Camera:edgeScroll(dt)
    if not love.window.hasFocus() then return end
    local mx, my = love.mouse.getPosition()
    local w, h = love.graphics.getDimensions()
    local EDGE = config.EDGE_SCROLL_MARGIN
    local sx, sy = 0, 0
    if mx < EDGE then sx = -1 elseif mx > w - EDGE then sx = 1 end
    if my < EDGE then sy = -1 elseif my > h - EDGE then sy = 1 end
    if sx ~= 0 or sy ~= 0 then
        local step = config.EDGE_SCROLL_SPEED * dt
        self:panScreen(sx * step, sy * step)
    end
end

-- Right-drag panning: move the map under the cursor.
function Camera:drag(dx, dy)
    self:panScreen(-dx, -dy)
end

function Camera:zoomBy(amount)
    self.zoom = math.max(config.CAMERA_MIN_ZOOM,
                math.min(config.CAMERA_MAX_ZOOM, self.zoom + amount))
end

function Camera:attach()
    local cx, cy = Iso.project(self.gx, self.gy)
    -- Fold into one translate and SNAP to whole pixels so tile edges don't
    -- shimmer/crawl as the map scrolls.
    local ox = math.floor(love.graphics.getWidth()  / 2 - cx * self.zoom + 0.5)
    local oy = math.floor(love.graphics.getHeight() / 2 - cy * self.zoom + 0.5)
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(self.zoom, self.zoom)
end

function Camera:detach()
    love.graphics.pop()
end

-- Ground coordinate -> screen pixel (matches attach()'s transform, incl. the
-- pixel snap). Used for on-screen UI hints like the mission pointer.
function Camera:worldToScreen(gx, gy)
    local cx, cy = Iso.project(self.gx, self.gy)
    local ox = math.floor(love.graphics.getWidth()  / 2 - cx * self.zoom + 0.5)
    local oy = math.floor(love.graphics.getHeight() / 2 - cy * self.zoom + 0.5)
    local ix, iy = Iso.project(gx, gy, 0)
    return ix * self.zoom + ox, iy * self.zoom + oy
end

-- Screen pixel -> ground coordinate (assumes the click is on the water).
function Camera:screenToWorld(sx, sy)
    local cx, cy = Iso.project(self.gx, self.gy)
    local isoX = (sx - love.graphics.getWidth()  / 2) / self.zoom + cx
    local isoY = (sy - love.graphics.getHeight() / 2) / self.zoom + cy
    return Iso.unproject(isoX, isoY)
end

-- Ground-space bounding box of what's on screen, for tile culling.
function Camera:groundBounds()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local minGx, minGy = math.huge, math.huge
    local maxGx, maxGy = -math.huge, -math.huge
    for _, corner in ipairs({ {0, 0}, {w, 0}, {0, h}, {w, h} }) do
        local gx, gy = self:screenToWorld(corner[1], corner[2])
        minGx = math.min(minGx, gx); maxGx = math.max(maxGx, gx)
        minGy = math.min(minGy, gy); maxGy = math.max(maxGy, gy)
    end
    return minGx, minGy, maxGx, maxGy
end

return Camera
