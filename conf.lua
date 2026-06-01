-- conf.lua
-- LÖVE reads this BEFORE the game starts to configure the window and modules.
-- See: https://love2d.org/wiki/Config_Files
--
-- We keep the window windowed + resizable here so development is comfortable.
-- Whether the game *starts* in fullscreen is decided at runtime in main.lua
-- (see src/config.lua -> START_FULLSCREEN), because we want to pick the
-- monitor's resolution dynamically.

function love.conf(t)
    t.identity = "batspillet"          -- save folder name (see "Save game" note in README)
    t.version  = "11.3"                -- LÖVE version this game targets
    t.console  = false                 -- set true on Windows to get a debug console

    t.window.title      = "Båtspillet"
    t.window.width      = 1280
    t.window.height     = 800
    t.window.resizable  = true
    t.window.fullscreen = false        -- runtime decides; keep windowed for safety
    t.window.vsync      = 1            -- smooth + easy on old GPUs
    t.window.minwidth   = 640
    t.window.minheight  = 480
    t.window.highdpi    = true         -- crisp on Retina Macs

    -- Disable modules we do not use. Smaller footprint = friendlier to old Macs.
    t.modules.joystick = false
    t.modules.physics  = false         -- we do our own simple movement, no Box2D
end
