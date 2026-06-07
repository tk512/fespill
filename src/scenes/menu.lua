-- src/scenes/menu.lua
-- Title screen with a fun, exciting welcome: the words "Velkommen til
-- Båtspillet!" bounce in one letter at a time over a big water splash, and a
-- recorded voice (my kid) says the same thing once. Then a "Seil ut!" button.
-- Works with both keyboard (Enter/Space) and mouse (click the button).

local config = require("src.config")
local Assets = require("src.assets")
local utf8 = require("utf8")

local Menu = {}

local TAU = math.pi * 2

-- Bouncy "elastic" ease: shoots past 1 then wobbles back. Great for a letter
-- springing into place. p in 0..1 -> value around 0..~1.1.
local function easeOutElastic(p)
    if p <= 0 then return 0 end
    if p >= 1 then return 1 end
    local c4 = TAU / 3
    return 2 ^ (-10 * p) * math.sin((p * 10 - 0.75) * c4) + 1
end

local function clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

-- Build the biggest font for `text` that still fits within targetW (capped at
-- maxSize). Lets the welcome title be HUGE without overflowing the screen.
local function fitFont(text, targetW, maxSize)
    local size = math.floor(maxSize)
    local f = love.graphics.newFont(size)
    local w = f:getWidth(text)
    if w > targetW then
        size = math.max(8, math.floor(size * targetW / w))
        f = love.graphics.newFont(size)
    end
    return f
end

function Menu:load(game)
    self.game = game
    self.t = 0                 -- time, for gentle animation

    -- BIG welcome fonts, sized to the screen so the words really stand out.
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    self.welcomeFont = fitFont("Velkommen til", sw * 0.48, sh * 0.12)
    self.titleFont   = fitFont("Båtspillet!",   sw * 0.75, sh * 0.30)

    self.boats = {}            -- a few decorative boats drifting by
    for i = 1, 5 do
        self.boats[i] = {
            x = love.math.random(0, love.graphics.getWidth()),
            y = love.math.random(love.graphics.getHeight() * 0.4, love.graphics.getHeight()),
            speed = love.math.random(20, 50),
            color = self.game.data.boats[love.math.random(#self.game.data.boats)].color,
        }
    end

    -- Exciting welcome timeline: the voice speaks FIRST (words bounce in to
    -- match), THEN the water splash erupts with a wave-crash sound.
    self.splash = {}
    self.splashFired = false
    Assets.playVoice("velkommen")   -- my kid: "Velkommen til Båtspillet!" (plays once)

    -- When does the splash/crash happen? Right after the voice finishes. If
    -- there's no voice file (or audio is off), still splash once the words land.
    local v = Assets.voice and Assets.voice.velkommen
    if v and config.AUDIO_ON then
        self.splashAt = v:getDuration() + 0.1
        Assets.setMusicVolume(0.25)  -- duck the music so the voice is clear
    else
        self.splashAt = 1.8
    end
end

-- A burst of water droplets + foam erupting from the middle of the screen.
function Menu:spawnSplash()
    local cx = love.graphics.getWidth() / 2
    local cy = love.graphics.getHeight() * 0.40
    for i = 1, 140 do
        local ang = -math.pi / 2 + (love.math.random() - 0.5) * 2.4  -- mostly upward
        local spd = love.math.random(220, 720)
        local kind = love.math.random()
        self.splash[i] = {
            x = cx + (love.math.random() - 0.5) * 60,
            y = cy,
            vx = math.cos(ang) * spd,
            vy = math.sin(ang) * spd,
            life = 0,
            ttl = love.math.random(0.7, 1.6),
            r = love.math.random(2, 6),
            -- mostly water-blue, some white foam, a few gold sparkles
            foam = kind > 0.65,
            gold = kind > 0.92,
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

    -- After the voice finishes: erupt the splash + crash, restore the music.
    if not self.splashFired and self.t >= self.splashAt then
        self.splashFired = true
        self:spawnSplash()
        Assets.playSfx("wave_crash")
        Assets.setMusicVolume(1.0)
    end

    -- Splash droplets: arc out under gravity, then fade.
    for _, p in ipairs(self.splash) do
        p.life = p.life + dt
        p.vy = p.vy + 1400 * dt          -- gravity
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
    end
end

-- Compute the start button rectangle (also used for click hit-testing).
function Menu:buttonRect()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local w, h = 320, 80
    return sw / 2 - w / 2, sh * 0.62, w, h
end

-- Draw a string letter-by-letter, each letter springing in (elastic bounce)
-- with a staggered delay and a gentle ongoing wobble. Centered on cx.
function Menu:bouncyText(font, text, cx, baselineY, startDelay, hueBase)
    love.graphics.setFont(font)      -- print() uses the CURRENT font, so set it!
    local total = font:getWidth(text)
    local x = cx - total / 2
    local perLetter = 0.06           -- stagger between letters
    -- Split into UTF-8 characters (so "å" stays one letter, not raw bytes).
    local chars = {}
    for _, code in utf8.codes(text) do chars[#chars + 1] = utf8.char(code) end
    for i = 1, #chars do
        local ch = chars[i]
        local cw = font:getWidth(ch)
        if ch ~= " " then
            local appear = (self.t - startDelay - (i - 1) * perLetter)
            local p = clamp01(appear / 0.7)
            local e = easeOutElastic(p)
            -- Letters are ALWAYS drawn full size (scale 1). The bounce is done
            -- purely as a vertical drop-in + a gentle ongoing bob, so the glyphs
            -- can never end up shrunken.
            local dropY = (1 - e) * -font:getHeight() * 0.6
            local settle = clamp01(appear)
            local bob = math.sin(self.t * 3 + i * 0.5) * 8 * settle
            -- cheerful shifting colors
            local hue = hueBase + i * 0.7 + self.t * 1.5
            local r = 0.6 + 0.4 * math.sin(hue)
            local g = 0.6 + 0.4 * math.sin(hue + 2.1)
            local bl = 0.6 + 0.4 * math.sin(hue + 4.2)
            local lx = x + cw / 2
            local ly = baselineY + dropY + bob
            local ox, oy = cw / 2, font:getHeight() / 2
            -- soft drop shadow for depth
            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.print(ch, lx + 6, ly + 8, 0, 1, 1, ox, oy)
            -- clean dark outline: a tight ring of copies (small radius so it
            -- reads as a solid stroke, not separate ghost letters)
            local ow = math.max(2, font:getHeight() * 0.018)
            love.graphics.setColor(0.04, 0.06, 0.10)
            for k = 0, 11 do
                local a = k / 12 * TAU
                love.graphics.print(ch, lx + math.cos(a) * ow, ly + math.sin(a) * ow,
                    0, 1, 1, ox, oy)
            end
            -- bright cheerful letter on top
            love.graphics.setColor(r, g, bl)
            love.graphics.print(ch, lx, ly, 0, 1, 1, ox, oy)
        end
        x = x + cw
    end
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

    -- splash droplets behind the text
    for _, p in ipairs(self.splash) do
        local a = clamp01(1 - p.life / p.ttl)
        if a > 0 then
            if p.gold then
                love.graphics.setColor(c.gold[1], c.gold[2], c.gold[3], a)
            elseif p.foam then
                love.graphics.setColor(1, 1, 1, a)
            else
                love.graphics.setColor(c.wave[1], c.wave[2], c.wave[3], a)
            end
            love.graphics.circle("fill", p.x, p.y, p.r)
        end
    end

    -- Translucent banner behind the words so they pop off the bright sky.
    local bandA = clamp01(self.t / 0.4) * 0.30
    love.graphics.setColor(0.05, 0.08, 0.14, bandA)
    love.graphics.rectangle("fill", 0, sh * 0.05, sw, sh * 0.56)

    -- Exciting welcome: two big bouncing lines.
    self:bouncyText(self.welcomeFont, "Velkommen til", sw / 2, sh * 0.16, 0.10, 0.0)
    self:bouncyText(self.titleFont,   "Båtspillet!",   sw / 2, sh * 0.42, 0.55, 3.0)

    -- Start button (appears after the welcome has bounced in)
    local btnIn = clamp01((self.t - 1.6) / 0.5)
    if btnIn > 0 then
        local bx, by, bw, bh = self:buttonRect()
        local hover = self:pointInButton(love.mouse.getPosition())
        local pop = 0.85 + 0.15 * btnIn
        love.graphics.push()
        love.graphics.translate(bx + bw / 2, by + bh / 2)
        love.graphics.scale(pop, pop)
        love.graphics.translate(-(bx + bw / 2), -(by + bh / 2))
        love.graphics.setColor(hover and c.gold or {0.95, 0.75, 0.2})
        love.graphics.rectangle("fill", bx, by, bw, bh, 16, 16)
        love.graphics.setColor(c.text_dark)
        love.graphics.setFont(self.game.fonts.big)
        local label = "Seil ut!"          -- "Set sail!"
        love.graphics.print(label,
            bx + bw / 2 - self.game.fonts.big:getWidth(label) / 2,
            by + bh / 2 - self.game.fonts.big:getHeight() / 2)
        love.graphics.pop()
    end

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

-- Leaving the menu early shouldn't leave the music ducked.
function Menu:start()
    Assets.setMusicVolume(1.0)
    self.game:setScene("world")
end

function Menu:keypressed(key)
    if key == "return" or key == "space" or key == "kpenter" then
        self:start()
    end
end

function Menu:mousepressed(x, y, button)
    if button == 1 and self:pointInButton(x, y) then
        self:start()
    end
end

return Menu
