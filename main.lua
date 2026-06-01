-- main.lua
-- Entry point. LÖVE calls the love.* callbacks below.
-- We keep this file tiny: it just forwards every event to the Game object,
-- which owns the scene manager and global state. (See src/game.lua.)

local Game = require("src.game")

function love.load()
    Game:load()
end

function love.update(dt)
    Game:update(dt)
end

function love.draw()
    Game:draw()
end

function love.keypressed(key, scancode, isrepeat)
    Game:keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button)
    Game:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    Game:mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    Game:mousemoved(x, y, dx, dy)
end

function love.wheelmoved(dx, dy)
    Game:wheelmoved(dx, dy)
end

function love.resize(w, h)
    Game:resize(w, h)
end

function love.quit()
    Game:quit()
end
