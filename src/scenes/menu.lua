-- src/scenes/menu.lua
-- Title screen. One job: show the game name and a "Start" button.
-- Works with both keyboard (Enter/Space) and mouse (click the button).

local config = require("src.config")

local Menu = {}

function Menu:load(game)
    self.game = game
    self.t = 0                 -- time, for gentle animation
    self.boats = {}            -- a few decorative boats drifting by
    for i = 1, 5 do
        self.boats[i] = {
            x = love.math.random(0, love.graphics.getWidth()),
            y = love.math.random(love.graphics.getHeight() * 0.4, love.graphics.getHeight()),
            speed = love.math.random(20, 50),
            color = self.game.data.boats[love.math.random(#self.game.data.boats)].color,
        }
    end
end

function Menu:update(dt)
    self.t = self.t + dt
    local w = love.graphics.getWidth()
    for _, b in ipairs(self.boats) do
        b.x = b.x + b.speed * dt
        if b.x > w + 30 then b.x = -30 end
    end
end

-- Compute the start button rectangle (also used for click hit-testing).
function Menu:buttonRect()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local w, h = 320, 80
    return sw / 2 - w / 2, sh * 0.58, w, h
end

function Menu:draw()
    local c = config.colors
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- Sky-to-sea gradient background (drawn as two big rectangles + band).
    love.graphics.setColor(0.55, 0.80, 0.95)
    love.graphics.rectangle("fill", 0, 0, sw, sh * 0.45)
    love.graphics.setColor(c.water_top)
    love.graphics.rectangle("fill", 0, sh * 0.40, sw, sh)

    -- a friendly sun
    love.graphics.setColor(1, 0.95, 0.6)
    love.graphics.circle("fill", sw * 0.8, sh * 0.18, 50)

    -- decorative drifting boats
    for _, b in ipairs(self.boats) do
        love.graphics.setColor(b.color)
        love.graphics.polygon("fill", b.x, b.y - 14, b.x + 12, b.y + 8, b.x - 12, b.y + 8)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.ellipse("fill", b.x, b.y + 12, 16, 4)
    end

    -- Title with a soft bob
    love.graphics.setFont(self.game.fonts.title)
    local title = "Båtspillet"
    local bob = math.sin(self.t * 1.5) * 6
    local tw = self.game.fonts.title:getWidth(title)
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.print(title, sw / 2 - tw / 2 + 3, sh * 0.18 + bob + 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(title, sw / 2 - tw / 2, sh * 0.18 + bob)

    -- Start button
    local bx, by, bw, bh = self:buttonRect()
    local hover = self:pointInButton(love.mouse.getPosition())
    love.graphics.setColor(hover and c.gold or {0.95, 0.75, 0.2})
    love.graphics.rectangle("fill", bx, by, bw, bh, 16, 16)
    love.graphics.setColor(c.text_dark)
    love.graphics.setFont(self.game.fonts.big)
    local label = "Seil ut!"          -- "Set sail!"
    love.graphics.print(label,
        bx + bw / 2 - self.game.fonts.big:getWidth(label) / 2,
        by + bh / 2 - self.game.fonts.big:getHeight() / 2)

    -- footer hint
    love.graphics.setFont(self.game.fonts.small)
    love.graphics.setColor(c.text_dark)
    local hint = "Trykk ENTER eller klikk for å starte   •   F11 = fullskjerm   •   M = lyd av/på"
    love.graphics.print(hint, sw / 2 - self.game.fonts.small:getWidth(hint) / 2, sh * 0.9)

    love.graphics.setColor(1, 1, 1)
end

function Menu:pointInButton(mx, my)
    local bx, by, bw, bh = self:buttonRect()
    return mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
end

function Menu:keypressed(key)
    if key == "return" or key == "space" or key == "kpenter" then
        self.game:setScene("world")
    end
end

function Menu:mousepressed(x, y, button)
    if button == 1 and self:pointInButton(x, y) then
        self.game:setScene("world")
    end
end

return Menu
