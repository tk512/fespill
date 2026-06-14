-- src/systems/loader.lua
-- Cooperative chunked loading. The world build is heavy enough to block for a
-- couple of seconds; running it inside a coroutine and calling Loader.tick()
-- inside the big loops lets it run in small time-slices so the loading screen
-- can animate between slices.
--
-- The loading scene sets Loader.deadline = now + budget before each resume.
-- tick() yields once that budget is used up (and only when actually running
-- inside a coroutine). Outside a coroutine — or a normal/F5 synchronous load —
-- deadline stays math.huge so tick() does nothing and the build runs straight
-- through with no behaviour change.

local Loader = { deadline = math.huge }

function Loader.tick()
    if Loader.deadline ~= math.huge
        and coroutine.running()
        and love.timer.getTime() >= Loader.deadline then
        coroutine.yield()
    end
end

return Loader
