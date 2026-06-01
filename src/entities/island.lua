-- src/entities/island.lua
-- NOTE: Islands are now part of the procedural heightmap (src/systems/terrain.lua):
-- the terrain engine generates big landmasses with real elevation from the
-- `config.ISLANDS` domes + hill noise, classifies tiles, and handles the
-- boat's land collision. The world's discoverable landmarks come from
-- `terrain.islandCenters`.
--
-- This file is kept (the project structure calls for it) as a tiny optional
-- helper for treating an island as a logical point — e.g. future quests that
-- reference a specific island by id. It is not used by the core loop.

local Island = {}
Island.__index = Island

function Island.new(x, y, id)
    return setmetatable({ x = x, y = y, id = id }, Island)
end

function Island:distanceTo(gx, gy)
    local dx, dy = gx - self.x, gy - self.y
    return math.sqrt(dx * dx + dy * dy)
end

return Island
