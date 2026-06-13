-- src/ui/retro.lua
-- Shared "early-90s strategy game" drawing helpers, so the title screen and the
-- dock/briefing screen use ONE chunky-bevel look instead of duplicating it.
--
--   Retro.bevel(x, y, w, h, face, hi, lo, t [, raised])
--       A filled rectangle with a chunky 3D edge: light top/left + dark
--       bottom/right for a RAISED look, swapped for a SUNKEN (inset) groove.
--       `t` is the edge thickness in pixels. raised defaults to true.
--
--   Retro.WOOD  — the cosy warm-wood palette (matches the dock screen's "cosy"
--                 theme) so frames, signs and panels are all the same family.

local Retro = {}

-- Warm-wood palette shared across the retro UI (mirrors portscreen's cosy theme)
Retro.WOOD = {
    face   = {0.40, 0.29, 0.19},
    hi     = {0.62, 0.46, 0.30},
    lo     = {0.20, 0.14, 0.09},
    accent = {0.95, 0.80, 0.36},
    text   = {0.96, 0.91, 0.76},
    deep   = {0.28, 0.18, 0.11},   -- darker carved/recessed wood
}

function Retro.bevel(x, y, w, h, face, hi, lo, t, raised)
    if raised == nil then raised = true end
    love.graphics.setColor(face)
    love.graphics.rectangle("fill", x, y, w, h)
    local a, b = hi, lo
    if not raised then a, b = lo, hi end
    love.graphics.setColor(a)
    love.graphics.rectangle("fill", x, y, w, t)
    love.graphics.rectangle("fill", x, y, t, h)
    love.graphics.setColor(b)
    love.graphics.rectangle("fill", x, y + h - t, w, t)
    love.graphics.rectangle("fill", x + w - t, y, t, h)
end

return Retro
