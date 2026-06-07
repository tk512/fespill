-- src/ui/hud.lua
-- Heads-up display, drawn in SCREEN space (after the camera is detached).
-- Shows coins, the current boat + cargo load, contextual port prompts, and
-- short-lived "toast" messages (e.g. "+15 gull!"). Text is Norwegian.

local config = require("src.config")

local HUD = {}

-- Draw a coin icon at (x,y) with radius r.
local function coin(x, y, r)
    local c = config.colors
    love.graphics.setColor(c.gold)
    love.graphics.circle("fill", x, y, r)
    love.graphics.setColor(0.8, 0.6, 0.05)
    love.graphics.circle("line", x, y, r)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("fill", x - r * 0.3, y - r * 0.3, r * 0.25)
end

local function panel(x, y, w, h)
    local c = config.colors
    love.graphics.setColor(c.panel[1], c.panel[2], c.panel[3], 0.78)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
end

-- world exposes: game (for coins + fonts), boat, cargoSystem, nearPort, toast.
function HUD.draw(world)
    local c     = config.colors
    local fonts = world.game.fonts
    local sw    = love.graphics.getWidth()
    local sh    = love.graphics.getHeight()

    -- ── Top-left: gold + boat + cargo ───────────────────────────────────
    love.graphics.setFont(fonts.normal)
    panel(16, 16, 230, 84)
    coin(40, 42, 12)
    love.graphics.setColor(c.text)
    love.graphics.print(tostring(world.game.state.coins) .. " gull", 60, 30)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(c.text)
    love.graphics.print("Båt: " .. world.boat.def.name, 30, 60)
    love.graphics.print(
        "Last: " .. world.boat:cargoCount() .. " / " .. world.boat.capacity,
        30, 78)

    -- ── Bottom-left: controls hint ──────────────────────────────────────
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(c.text[1], c.text[2], c.text[3], 0.8)
    local hint = "Klikk = seil dit   •   Mus mot kanten = flytt kart   •   C = midtstill   •   MELLOMROM = last/lever   •   ESC = meny"
    love.graphics.print(hint, 16, sh - 26)

    -- ── Top-center: current mission banner (so it's clear we're ON a job) ──
    if world.boat.cargo[1] then
        HUD.drawMission(world, sw, sh, c, fonts)
    end

    -- ── Bottom-center: contextual port prompt ───────────────────────────
    if world.nearPort then
        HUD.drawPortPrompt(world, sw, sh, c, fonts)
    end

    -- ── Center: toast message ───────────────────────────────────────────
    if world.toast and world.toast.timer > 0 then
        HUD.drawToast(world, sw, sh, c, fonts)
    end

    love.graphics.setColor(1, 1, 1)
end

-- A small icon for a mission (passenger / fish / generic), drawn at (x,y).
local function missionIcon(kind, x, y, s)
    if kind == "passenger" then
        love.graphics.setColor(0.95, 0.80, 0.55)
        love.graphics.rectangle("fill", x - s * 0.22, y - s * 0.5, s * 0.44, s * 0.4)
        love.graphics.setColor(0.30, 0.45, 0.70)
        love.graphics.rectangle("fill", x - s * 0.38, y - s * 0.08, s * 0.76, s * 0.5)
    elseif kind == "fish" then
        love.graphics.setColor(0.55, 0.68, 0.82)
        love.graphics.rectangle("fill", x - s * 0.42, y - s * 0.2, s * 0.66, s * 0.4)
        love.graphics.polygon("fill", x + s * 0.24, y, x + s * 0.46, y - s * 0.26, x + s * 0.46, y + s * 0.26)
    else
        love.graphics.setColor(0.60, 0.45, 0.28)
        love.graphics.rectangle("fill", x - s * 0.36, y - s * 0.36, s * 0.72, s * 0.72)
    end
end

-- Top-center banner: "Oppdrag: N <icon> → <BY>" with the town's flag colour.
function HUD.drawMission(world, sw, sh, c, fonts)
    local m = world.boat.cargo[1]
    love.graphics.setFont(fonts.normal)
    local dest = m.toName
    local w = 320 + fonts.normal:getWidth(dest)
    local x, y = sw / 2 - w / 2, 16
    panel(x, y, w, 56)

    love.graphics.setColor(c.gold)
    love.graphics.print("Oppdrag:", x + 16, y + 14)
    local ix = x + 16 + fonts.normal:getWidth("Oppdrag:") + 28

    -- count + icon
    love.graphics.setColor(c.text)
    love.graphics.print("x" .. m.count, ix - 22, y + 14)
    missionIcon(m.icon, ix + 18, y + 28, 26)

    -- arrow + destination flag + name in its town colour
    love.graphics.setColor(c.text)
    love.graphics.print("→", ix + 40, y + 14)
    local nx = ix + 40 + fonts.normal:getWidth("→ ")
    love.graphics.setColor(m.color or c.text)
    love.graphics.rectangle("fill", nx, y + 16, 16, 22)
    love.graphics.print(dest, nx + 24, y + 14)

    love.graphics.setColor(1, 1, 1)
end

function HUD.drawPortPrompt(world, sw, sh, c, fonts)
    local port  = world.nearPort
    local boat  = world.boat
    local offer = world.cargoSystem:offerAt(port.id)

    -- What can the player do here right now?
    local lines = {}
    -- Deliveries waiting for this port?
    for _, item in ipairs(boat.cargo) do
        if item.toId == port.id then
            lines[#lines + 1] = "Lever " .. item.type .. " (+" .. item.reward .. " gull)"
        end
    end
    -- Pickup available?
    if offer and boat:hasRoom() then
        lines[#lines + 1] = "Last " .. offer.type .. "  →  " .. offer.toName
    elseif offer and not boat:hasRoom() then
        lines[#lines + 1] = "Båten er full!"
    end

    if #lines == 0 then return end

    love.graphics.setFont(fonts.normal)
    local w = 360
    for _, l in ipairs(lines) do
        w = math.max(w, fonts.normal:getWidth(l) + 60)
    end
    local h = 44 + #lines * 24
    local x = sw / 2 - w / 2
    local y = sh - h - 70

    panel(x, y, w, h)
    love.graphics.setColor(c.gold)
    love.graphics.setFont(fonts.normal)
    local title = "Trykk MELLOMROM"
    love.graphics.print(title, sw / 2 - fonts.normal:getWidth(title) / 2, y + 10)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(c.text)
    for i, l in ipairs(lines) do
        love.graphics.print(l, sw / 2 - fonts.small:getWidth(l) / 2, y + 40 + (i - 1) * 22)
    end
end

function HUD.drawToast(world, sw, sh, c, fonts)
    local t = world.toast
    local alpha = math.min(1, t.timer)  -- fade out in the last second
    love.graphics.setFont(fonts.big)
    local w = fonts.big:getWidth(t.text)
    local x = sw / 2 - w / 2
    local y = sh * 0.30 - t.rise  -- floats upward as it fades

    love.graphics.setColor(0, 0, 0, 0.4 * alpha)
    love.graphics.print(t.text, x + 2, y + 2)
    love.graphics.setColor(c.gold[1], c.gold[2], c.gold[3], alpha)
    love.graphics.print(t.text, x, y)
end

return HUD
