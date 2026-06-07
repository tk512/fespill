-- src/ui/portscreen.lua
-- The "docking" screen: a big, reading-free modal that pops up when the boat
-- reaches a port. It shows a photo of the town, a spoken/iconic mission
-- ("Ta 2 passasjerer til Fjellvik"), a 🔊 replay button, and one big "Seil!"
-- button to confirm and head back out.
--
-- It is an OVERLAY owned by the world scene (not a separate scene), so the
-- boat / camera / cargo all stay in memory while it is open. The world freezes
-- itself while `world.dock` is set and routes input here.
--
-- Three modes (decided by world:openDock):
--   "offer"   — this town wants you to carry passengers/goods somewhere
--   "deliver" — you brought someone/something here: celebrate + gold
--   "visit"   — nothing to do right now (just a friendly hello)

local config = require("src.config")
local Assets = require("src.assets")

local PortScreen = {}
PortScreen.__index = PortScreen

-- info = { mode, offer, earned, delivered }
function PortScreen.new(world, port, info)
    local self = setmetatable({}, PortScreen)
    self.world = world
    self.port  = port
    self.mode  = info.mode
    self.offer = info.offer
    self.earned    = info.earned or 0
    self.delivered = info.delivered or 0
    self.t = 0
    self:playVoice()
    return self
end

-- Try a recorded instruction for this town; fall back to a horn so the button
-- always does *something* until you drop real voice files in assets/voice/.
function PortScreen:playVoice()
    if not Assets.playNamedVoice("dock_" .. self.port.id) then
        Assets.playSfx("horn")
    end
end

function PortScreen:update(dt)
    self.t = self.t + dt
end

-- ── Layout (computed in one place so draw + hit-testing always agree) ───────
function PortScreen:layout()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local w = math.min(760, sw * 0.82)
    local h = math.min(580, sh * 0.86)
    local x, y = (sw - w) / 2, (sh - h) / 2
    local photoH = h * 0.40
    local btnW, btnH = w * 0.55, 76
    return {
        sw = sw, sh = sh,
        x = x, y = y, w = w, h = h,
        photo   = { x = x, y = y, w = w, h = photoH },
        speaker = { x = x + w - 74, y = y + 14, w = 60, h = 60 },
        seil    = { x = x + (w - btnW) / 2, y = y + h - btnH - 22, w = btnW, h = btnH },
        contentY = y + photoH,
        contentH = h - photoH - btnH - 44,
    }
end

local function inRect(r, mx, my)
    return mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end

-- ── Input ──────────────────────────────────────────────────────────────────
function PortScreen:mousepressed(mx, my, button)
    if button ~= 1 then return end
    local L = self:layout()
    if inRect(L.speaker, mx, my) then
        self:playVoice()
    elseif inRect(L.seil, mx, my) then
        self:confirm()
    elseif not inRect(L, mx, my) then
        self:confirm()                      -- tapping outside the card also leaves
    end
end

function PortScreen:keypressed(key)
    if key == "space" or key == "return" or key == "kpenter" then
        self:confirm()
    end
end

function PortScreen:confirm()
    if self.mode == "offer" and self.offer then
        self.world.cargoSystem:tryPickup(self.world.boat, self.port)
        Assets.playSfx("horn")
        self.world:showToast("Ombord!")
    end
    self.world.dock = nil                    -- close; world resumes next frame
end

-- ── Drawing ─────────────────────────────────────────────────────────────────
function PortScreen:draw()
    local L = self:layout()
    local fonts = self.world.game.fonts

    -- dim the frozen world behind us
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, L.sw, L.sh)

    -- a gentle pop-in
    local pop = math.min(1, self.t / 0.18)
    love.graphics.push()
    love.graphics.translate(L.x + L.w / 2, L.y + L.h / 2)
    love.graphics.scale(0.92 + 0.08 * pop, 0.92 + 0.08 * pop)
    love.graphics.translate(-(L.x + L.w / 2), -(L.y + L.h / 2))

    -- card
    love.graphics.setColor(0.97, 0.95, 0.90)
    love.graphics.rectangle("fill", L.x, L.y, L.w, L.h, 22, 22)

    self:drawPhoto(L)
    self:drawSpeaker(L)
    self:drawContent(L, fonts)
    self:drawSeilButton(L, fonts)

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

-- Town photo: a real image from assets/ports/photos/<id>.png if present, else a
-- cute procedurally-drawn "postcard" so it always looks intentional.
function PortScreen:drawPhoto(L)
    local p = L.photo
    love.graphics.setScissor(p.x, p.y, p.w, p.h)
    local img = Assets.portPhoto(self.port.id)
    if img then
        local s = math.max(p.w / img:getWidth(), p.h / img:getHeight())
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img, p.x + p.w / 2, p.y + p.h / 2, 0, s, s,
            img:getWidth() / 2, img:getHeight() / 2)
    else
        self:drawPostcard(p)
    end
    love.graphics.setScissor()

    -- town-name banner across the bottom of the photo
    local fonts = self.world.game.fonts
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", p.x, p.y + p.h - 46, p.w, 46)
    love.graphics.setFont(fonts.big)
    love.graphics.setColor(1, 1, 1)
    local name = self.port.name
    love.graphics.print(name, p.x + p.w / 2 - fonts.big:getWidth(name) / 2, p.y + p.h - 44)
end

-- Deterministic per-town placeholder scene (sky, sun, sea, little houses).
function PortScreen:drawPostcard(p)
    local col = self.port.color
    -- sky
    love.graphics.setColor(0.55, 0.78, 0.93)
    love.graphics.rectangle("fill", p.x, p.y, p.w, p.h)
    -- sun
    love.graphics.setColor(1, 0.95, 0.6)
    love.graphics.circle("fill", p.x + p.w * 0.82, p.y + p.h * 0.28, p.h * 0.13)
    -- a row of little houses with this town's roof color
    local n = 5
    local hash = #self.port.id
    for i = 0, n - 1 do
        local hx = p.x + p.w * (0.10 + i * 0.17)
        local hh = p.h * (0.20 + ((hash + i * 7) % 5) * 0.03)
        local hw = p.w * 0.11
        local hy = p.y + p.h * 0.62 - hh
        love.graphics.setColor(0.92, 0.88, 0.80)        -- wall
        love.graphics.rectangle("fill", hx, hy, hw, hh)
        love.graphics.setColor(col)                     -- roof
        love.graphics.polygon("fill", hx - 3, hy, hx + hw + 3, hy, hx + hw / 2, hy - p.h * 0.10)
    end
    -- sea
    love.graphics.setColor(0.31, 0.49, 0.60)
    love.graphics.rectangle("fill", p.x, p.y + p.h * 0.62, p.w, p.h * 0.38)
    love.graphics.setColor(0.52, 0.64, 0.70, 0.5)
    for i = 0, 6 do
        local wy = p.y + p.h * (0.70 + i * 0.04)
        love.graphics.line(p.x, wy, p.x + p.w, wy)
    end
end

function PortScreen:drawSpeaker(L)
    local s = L.speaker
    local pulse = 1 + 0.06 * math.sin(self.t * 6)
    love.graphics.setColor(0.20, 0.55, 0.85)
    love.graphics.circle("fill", s.x + s.w / 2, s.y + s.h / 2, s.w / 2 * pulse)
    -- speaker glyph
    love.graphics.setColor(1, 1, 1)
    local cx, cy = s.x + s.w / 2, s.y + s.h / 2
    love.graphics.polygon("fill", cx - 12, cy - 6, cx - 4, cy - 6, cx + 3, cy - 13,
        cx + 3, cy + 13, cx - 4, cy + 6, cx - 12, cy + 6)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", "open", cx + 4, cy, 9, -0.8, 0.8)
    love.graphics.arc("line", "open", cx + 4, cy, 14, -0.8, 0.8)
    love.graphics.setLineWidth(1)
end

-- The mission itself, drawn big with icons (so a non-reader gets it).
function PortScreen:drawContent(L, fonts)
    local cx = L.x + L.w / 2
    local cy = L.contentY + L.contentH / 2
    love.graphics.setColor(0.16, 0.16, 0.18)

    if self.mode == "offer" and self.offer then
        local o = self.offer
        -- icon row: N little passengers / crates
        self:drawIconRow(o.icon, o.count, cx, cy - 34)
        -- "til <BY>" with the destination's flag color
        love.graphics.setFont(fonts.big)
        local noun = (o.mode == "passengers")
            and (o.count .. " passasjerer") or (o.count .. " " .. string.lower(o.type))
        local line1 = "Ta " .. noun
        local line2 = "til " .. o.toName
        love.graphics.setColor(0.16, 0.16, 0.18)
        love.graphics.print(line1, cx - fonts.big:getWidth(line1) / 2, cy + 6)
        -- destination name in its town color, with a little flag
        love.graphics.setColor(o.color or {0.3, 0.3, 0.3})
        love.graphics.print(line2, cx - fonts.big:getWidth(line2) / 2, cy + 6 + fonts.big:getHeight())

    elseif self.mode == "deliver" then
        self:drawIconRow("smile", math.max(1, self.delivered), cx, cy - 34)
        love.graphics.setFont(fonts.title)
        local t1 = "Bra jobba!"
        love.graphics.setColor(0.20, 0.55, 0.30)
        love.graphics.print(t1, cx - fonts.title:getWidth(t1) / 2, cy - 6)
        love.graphics.setFont(fonts.big)
        local t2 = "+" .. self.earned .. " gull"
        love.graphics.setColor(config.colors.gold)
        love.graphics.print(t2, cx - fonts.big:getWidth(t2) / 2, cy - 6 + fonts.title:getHeight())

    else -- visit
        love.graphics.setFont(fonts.big)
        local t = "Velkommen!"
        love.graphics.setColor(0.16, 0.16, 0.18)
        love.graphics.print(t, cx - fonts.big:getWidth(t) / 2, cy - fonts.big:getHeight() / 2)
    end
end

-- Draw `count` little icons centered on (cx, y).
function PortScreen:drawIconRow(kind, count, cx, y)
    count = math.min(count, 6)
    local size = 34
    local gap = size + 14
    local total = (count - 1) * gap
    for i = 1, count do
        self:drawIcon(kind, cx - total / 2 + (i - 1) * gap, y, size)
    end
end

function PortScreen:drawIcon(kind, x, y, s)
    if kind == "passenger" or kind == "smile" then
        love.graphics.setColor(0.95, 0.80, 0.55)            -- head
        love.graphics.circle("fill", x, y - s * 0.25, s * 0.28)
        love.graphics.setColor(0.30, 0.50, 0.75)            -- body
        love.graphics.arc("fill", x, y + s * 0.45, s * 0.5, math.pi, 2 * math.pi)
        if kind == "smile" then
            love.graphics.setColor(0.16, 0.16, 0.18)
            love.graphics.circle("fill", x - s * 0.10, y - s * 0.30, s * 0.04)
            love.graphics.circle("fill", x + s * 0.10, y - s * 0.30, s * 0.04)
        end
    elseif kind == "fish" then
        love.graphics.setColor(0.45, 0.60, 0.78)
        love.graphics.ellipse("fill", x, y, s * 0.5, s * 0.30)
        love.graphics.polygon("fill", x + s * 0.4, y, x + s * 0.6, y - s * 0.2, x + s * 0.6, y + s * 0.2)
    elseif kind == "apple" then
        love.graphics.setColor(0.80, 0.30, 0.25)
        love.graphics.circle("fill", x, y, s * 0.38)
        love.graphics.setColor(0.36, 0.27, 0.17)
        love.graphics.rectangle("fill", x - 2, y - s * 0.5, 4, s * 0.22)
    elseif kind == "flower" then
        love.graphics.setColor(0.90, 0.40, 0.60)
        for a = 0, 5 do
            local ang = a / 6 * math.pi * 2
            love.graphics.circle("fill", x + math.cos(ang) * s * 0.26, y + math.sin(ang) * s * 0.26, s * 0.16)
        end
        love.graphics.setColor(0.95, 0.85, 0.35)
        love.graphics.circle("fill", x, y, s * 0.16)
    else -- generic crate
        love.graphics.setColor(0.60, 0.45, 0.28)
        love.graphics.rectangle("fill", x - s * 0.4, y - s * 0.4, s * 0.8, s * 0.8, 3, 3)
        love.graphics.setColor(0.40, 0.30, 0.20)
        love.graphics.rectangle("line", x - s * 0.4, y - s * 0.4, s * 0.8, s * 0.8, 3, 3)
    end
end

function PortScreen:drawSeilButton(L, fonts)
    local b = L.seil
    local mx, my = love.mouse.getPosition()
    local hover = inRect(b, mx, my)
    love.graphics.setColor(hover and {0.30, 0.70, 0.40} or {0.25, 0.62, 0.35})
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 16, 16)
    love.graphics.setFont(fonts.big)
    love.graphics.setColor(1, 1, 1)
    local label = "Seil!"
    love.graphics.print(label, b.x + b.w / 2 - fonts.big:getWidth(label) / 2,
        b.y + b.h / 2 - fonts.big:getHeight() / 2)
end

return PortScreen
