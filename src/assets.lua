-- src/assets.lua
-- Central asset loader. Two jobs:
--   1. Load PNGs from assets/ ONCE and cache them. If a file is missing,
--      return nil so the entity can draw placeholder art instead. The game
--      therefore runs fine with zero image files (see CLAUDE.md req #9).
--   2. Generate retro 1990s-style sound effects + music IN CODE so there are
--      no audio files to ship either. All synthesis is wrapped in pcall so a
--      failure just means silence, never a crash.

local config = require("src.config")

local Assets = {}

-- ── Images ───────────────────────────────────────────────────────────────
-- cache value: an Image, or false meaning "checked, not present".
local imageCache = {}

local groundCache = {}  -- path -> y of the sprite's ground line (lowest opaque row + 1)

-- Find the lowest opaque pixel row, scanning from the bottom up. For an iso
-- tile sprite that's the bottom tip of its ground diamond — the point that
-- should touch the tile, regardless of transparent padding below it.
local function computeGroundY(data)
    local w, h = data:getWidth(), data:getHeight()
    for y = h - 1, 0, -1 do
        for x = 0, w - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0.3 then return y + 1 end
        end
    end
    return h
end

-- path is relative to assets/, e.g. "boats/boat1.png".
-- Returns the Image, or nil if it does not exist (caller draws placeholder).
function Assets.image(path)
    if imageCache[path] == nil then
        local full = "assets/" .. path
        if love.filesystem.getInfo(full) then
            local okd, data = pcall(love.image.newImageData, full)
            if okd then
                local img = love.graphics.newImage(data)
                img:setFilter("nearest", "nearest")  -- crisp pixel look
                imageCache[path]  = img
                groundCache[path] = computeGroundY(data)
            else
                imageCache[path] = false
            end
        else
            imageCache[path] = false
        end
    end
    local img = imageCache[path]
    if img then return img end
    return nil
end

-- The sprite's ground line (image-space y), used to anchor it flat on a tile.
function Assets.imageGroundY(path)
    return groundCache[path]
end

-- Harbor-master portrait for the docking screen: assets/ports/portraits/<id>.png
-- (or nil so the screen draws a pixel-art placeholder). Cached after first lookup.
local portraitCache = {}
function Assets.portPortrait(id)
    if portraitCache[id] == nil then
        local full = "assets/ports/portraits/" .. id .. ".png"
        if love.filesystem.getInfo(full) then
            local ok, img = pcall(love.graphics.newImage, full)
            portraitCache[id] = ok and img or false
        else
            portraitCache[id] = false
        end
    end
    return portraitCache[id] or nil
end

-- Town photo for the docking screen: assets/ports/photos/<id>.png (or nil so
-- the screen draws a procedural postcard instead). Cached after first lookup.
local photoCache = {}
function Assets.portPhoto(id)
    if photoCache[id] == nil then
        local full = "assets/ports/photos/" .. id .. ".png"
        if love.filesystem.getInfo(full) then
            local ok, img = pcall(love.graphics.newImage, full)
            photoCache[id] = ok and img or false
        else
            photoCache[id] = false
        end
    end
    return photoCache[id] or nil
end

-- ── Sound synthesis ────────────────────────────────────────────────────────
local RATE = 22050 -- low sample rate on purpose: small + lo-fi 90s feel

-- Build a SoundData from a per-sample function f(t, i) -> amplitude (-1..1).
local function render(seconds, f)
    local n = math.floor(seconds * RATE)
    local data = love.sound.newSoundData(n, RATE, 16, 1)
    for i = 0, n - 1 do
        local t = i / RATE
        local v = f(t, i)
        if v >  1 then v =  1 end
        if v < -1 then v = -1 end
        data:setSample(i, v)
    end
    return data
end

-- Simple ADSR-ish envelope: fade in over `atk`, fade out over `rel`.
local function env(t, dur, atk, rel)
    if t < atk then return t / atk end
    if t > dur - rel then return math.max(0, (dur - t) / rel) end
    return 1
end

local TAU = math.pi * 2

Assets.sounds = {}  -- name -> Source ("static")
Assets.music  = nil -- Source ("static", looping)

local function makeSounds()
    -- Coin pickup: two quick bright square-ish blips (classic arcade).
    Assets.sounds.coin = love.audio.newSource(render(0.18, function(t)
        local note = (t < 0.08) and 988 or 1319 -- B5 then E6
        local sq = (math.sin(TAU * note * t) > 0) and 0.5 or -0.5
        return sq * env(t, 0.18, 0.005, 0.05)
    end), "static")

    -- Delivery success: gentle 3-note ascending arpeggio (C-E-G).
    Assets.sounds.deliver = love.audio.newSource(render(0.5, function(t)
        local freqs = { 523, 659, 784 }
        local idx = math.min(3, math.floor(t / 0.16) + 1)
        local f = freqs[idx]
        return 0.45 * math.sin(TAU * f * t) * env(t, 0.5, 0.01, 0.15)
    end), "static")

    -- Boat horn: low two-tone honk with a little harmonic + slow vibrato.
    Assets.sounds.horn = love.audio.newSource(render(0.9, function(t)
        local base = (t < 0.45) and 196 or 147 -- G3 then D3
        local vib = 1 + 0.01 * math.sin(TAU * 5 * t)
        local s = math.sin(TAU * base * vib * t)
                + 0.5 * math.sin(TAU * base * 2 * vib * t)
        return 0.4 * s * env(t, 0.9, 0.03, 0.25)
    end), "static")

    -- Soft "bonk" used for bouncing off land/edges.
    Assets.sounds.bump = love.audio.newSource(render(0.15, function(t)
        return 0.35 * math.sin(TAU * 120 * t) * env(t, 0.15, 0.002, 0.1)
    end), "static")

    -- Wave crash: a swelling "whoosh" of filtered noise that breaks into foam
    -- and recedes, with a low boom underneath. Played after the welcome voice.
    local prev = 0
    local seed = 99173
    local function rnd()                       -- deterministic noise (no Math.random)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return (seed / 2147483648) * 2 - 1
    end
    Assets.sounds.wave_crash = love.audio.newSource(render(1.5, function(t)
        local raw = rnd()
        prev = prev * 0.85 + raw * 0.15        -- low-pass -> "shhhh" of water
        local amp
        if t < 0.35 then amp = (t / 0.35) ^ 2  -- swell up to the crash...
        else amp = math.max(0, 1 - (t - 0.35) / 1.15) end  -- ...then recede
        local boom = 0.4 * math.sin(TAU * 70 * t) * math.max(0, 1 - t / 0.6)
        return (prev * 2.0 + boom) * amp
    end), "static")

    -- "Leaving the dock": three short beeps (placeholder until a real recording
    -- is dropped in at assets/sfx/leave.ogg, which overrides this).
    Assets.sounds.leave = love.audio.newSource(render(0.55, function(t)
        for i = 0, 2 do
            local s = i * 0.17
            if t >= s and t < s + 0.11 then
                local sq = (math.sin(TAU * 740 * t) > 0) and 0.5 or -0.5
                return sq * env(t - s, 0.11, 0.005, 0.04)
            end
        end
        return 0
    end), "static")

    -- Cannon BOOM — horrific: a vicious crack, a deep sub-bass that plunges in
    -- pitch, a dissonant growl overtone, and a long low-passed rumble tail that
    -- lingers like distant thunder. A little clipping on purpose = grit.
    local boomRumble = 0
    Assets.sounds.cannon = love.audio.newSource(render(0.95, function(t)
        local crack  = rnd() * math.max(0, 1 - t / 0.03) * 1.2          -- sharp muzzle crack
        local subF   = 68 - 42 * t                                       -- deep pitch plunge
        local sub    = math.sin(TAU * subF * t) * math.max(0, 1 - t / 0.7)
        local growl  = 0.3 * math.sin(TAU * subF * 1.41 * t) * math.max(0, 1 - t / 0.5) -- dissonant tritone-ish
        boomRumble   = boomRumble * 0.9 + rnd() * 0.1                     -- low-pass rumble
        local rumble = boomRumble * math.max(0, 1 - t / 0.92) * 0.9
        return (sub * 1.05 + crack + growl + rumble) * env(t, 0.95, 0.0005, 0.32)
    end), "static")

    -- Cannonball HIT on the boat: a wet thud + a sad little downward "you lost
    -- coins" blip + a splash of noise.
    Assets.sounds.cannon_hit = love.audio.newSource(render(0.45, function(t)
        local thud   = math.sin(TAU * (150 - 130 * t) * t) * math.max(0, 1 - t / 0.25)
        local splash = rnd() * 0.5 * math.max(0, 1 - t / 0.3)
        local note   = (t < 0.18) and 392 or 294                    -- G4 -> D4 (downbeat)
        local sad    = math.sin(TAU * note * t) * 0.3
        return (thud * 0.7 + splash * 0.6 + sad) * env(t, 0.45, 0.002, 0.12)
    end), "static")

    -- Pirate WARNING — a cinematic horror stinger when the pirate appears: three
    -- VERY low, detuned impact hits that sink in pitch (each with a noise crash),
    -- over an ominous growling drone, with a dissonant high "tension strings"
    -- cluster that swells. Scary, but low/cinematic rather than ear-piercing.
    local warnRumble = 0
    Assets.sounds.pirate_warn = love.audio.newSource(render(1.7, function(t)
        local notes = { 73.4, 58.3, 46.2 }                           -- D2, A#1, F#1 — sinking dread
        local idx = math.min(3, math.floor(t / 0.46) + 1)
        local lt  = t - (idx - 1) * 0.46
        local f   = notes[idx]
        local hit = (math.sin(TAU * f * t) + 0.5 * math.sin(TAU * f * 2.02 * t)) -- detuned octave = grindy
                    * env(lt, 0.46, 0.004, 0.2)
        warnRumble = warnRumble * 0.88 + rnd() * 0.12
        local crash   = warnRumble * math.max(0, 1 - lt / 0.14) * 0.7   -- impact crash on each hit
        local growl   = 0.3 * math.sin(TAU * 46 * t) * (0.6 + 0.4 * math.sin(TAU * 8 * t)) -- dread drone
        local tension = (math.sin(TAU * 415 * t) + math.sin(TAU * 440 * t)) * 0.11 * math.min(1, t / 1.3)
        return (hit * 0.85 + crash + growl + tension) * env(t, 1.7, 0.01, 0.3)
    end), "static")
end

-- Ambient ocean: a long, quietly looping bed of filtered noise that swells
-- in and out like waves. Uses a tiny running low-pass to soften the noise.
local function makeAmbience()
    local prev = 0
    local seed = 12345
    local function rnd() -- deterministic noise (no Math.random dependency)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return (seed / 2147483648) * 2 - 1
    end
    Assets.sounds.ambience = love.audio.newSource(render(6.0, function(t)
        local raw = rnd()
        prev = prev * 0.92 + raw * 0.08          -- low-pass -> "shhh" of water
        local swell = 0.5 + 0.5 * math.sin(TAU * (t / 6.0)) -- slow wave rhythm
        return prev * 1.6 * swell
    end), "static")
    Assets.sounds.ambience:setLooping(true)
    Assets.sounds.ambience:setVolume(0.5)
end

-- Background music: a calm looping arpeggio over a simple chord progression,
-- polyphonic (a bass note + arpeggiated chord), deliberately lo-fi.
local function makeMusic()
    -- Chords as MIDI-ish frequencies. I-vi-IV-V-ish, major and friendly.
    local chords = {
        { 130.8, 164.8, 196.0 }, -- C major  (C3 E3 G3)
        { 110.0, 146.8, 174.6 }, -- A minor  (A2 D3 F3)
        { 174.6, 220.0, 261.6 }, -- F major  (F3 A3 C4)
        { 196.0, 246.9, 293.7 }, -- G major  (G3 B3 D4)
    }
    local chordDur = 2.0
    local total = chordDur * #chords -- 8 seconds, loops seamlessly

    Assets.music = love.audio.newSource(render(total, function(t)
        local ci = (math.floor(t / chordDur) % #chords) + 1
        local chord = chords[ci]
        local localT = t % chordDur

        -- Bass: root, gentle sine.
        local bass = 0.5 * math.sin(TAU * (chord[1] / 2) * t)

        -- Arpeggio: step through the chord notes, soft triangle-ish tone.
        local step = math.floor(localT / 0.25) % 3 + 1
        local nt = localT % 0.25
        local note = chord[step] * 2 -- up an octave so it sings above the bass
        local tone = math.sin(TAU * note * t)
        local pluck = math.max(0, 1 - nt / 0.25) -- each note decays
        local arp = 0.4 * tone * pluck

        return (bass + arp) * 0.6
    end), "static")
    Assets.music:setLooping(true)
    Assets.music:setVolume(config.MUSIC_VOLUME)
end

-- Voice clip(s): real recorded audio files (e.g. my kid saying the welcome).
-- Loaded from assets/ if present; missing files just mean no voice (no crash).
Assets.voice = {}  -- name -> Source ("static")

local function makeVoice()
    -- name -> filename under assets/
    local clips = { velkommen = "velkommen.ogg" }
    for name, file in pairs(clips) do
        local full = "assets/" .. file
        if love.filesystem.getInfo(full) then
            Assets.voice[name] = love.audio.newSource(full, "static")
        end
    end
end

-- Harbor "mood" themes that loop while the docking screen is open: a warm,
-- cosy arpeggio for friendly ports and a low, threatening drone for scary ones.
local function makeDockMoods()
    Assets.sounds.dock_cosy = love.audio.newSource(render(4.0, function(t)
        local chord = { 261.6, 329.6, 392.0, 329.6 }   -- C E G E (C major, friendly)
        local step  = math.floor((t % 2.0) / 0.5) % 4 + 1
        local nt    = t % 0.5
        local pluck = math.max(0, 1 - nt / 0.5)
        local bass  = 0.4 * math.sin(TAU * 130.8 * t)
        return (0.35 * math.sin(TAU * chord[step] * t) * pluck + bass * 0.5) * 0.5
    end), "static")
    Assets.sounds.dock_cosy:setLooping(true)

    Assets.sounds.dock_scary = love.audio.newSource(render(4.0, function(t)
        local drone = 0.5 * math.sin(TAU * 61.7 * t)            -- low rumble
        local trem  = 0.5 + 0.5 * math.sin(TAU * 6 * t)         -- nervous tremolo
        local minor = 0.25 * math.sin(TAU * 155.6 * t) * trem   -- minor third
        local clash = 0.15 * math.sin(TAU * 164.8 * t)          -- dissonant semitone
        return (drone + minor + clash) * 0.4
    end), "static")
    Assets.sounds.dock_scary:setLooping(true)

    -- Chase drone: an ominous pulsing low bed that loops while a pirate hunts you.
    Assets.sounds.chase = love.audio.newSource(render(4.0, function(t)
        local drone = 0.4 * math.sin(TAU * 55 * t)                 -- deep rumble (A1)
        local pulse = 0.55 + 0.45 * math.sin(TAU * 2.2 * t)        -- racing heartbeat
        local tens  = 0.2 * math.sin(TAU * 146.8 * t) * (0.5 + 0.5 * math.sin(TAU * 5 * t))
        return (drone * pulse + tens) * 0.45
    end), "static")
    Assets.sounds.chase:setLooping(true)
end

-- Replace synthesized sfx with real recordings if present (drop files in to
-- override): assets/sfx/<name>.ogg. e.g. assets/sfx/leave.ogg = the three beeps.
local function loadSfxFiles()
    -- Drop a real recording at assets/sfx/<name>.<ext> to override the synth.
    -- Any LÖVE-supported audio format works (ogg/mp3/flac/wav), tried in order.
    --   leave        — three "casting off" beeps
    --   cannon       — pirate cannon BOOM
    --   cannon_hit   — a ball striking your boat
    --   pirate_warn  — plays when a pirate appears
    local names = { "leave", "cannon", "cannon_hit", "pirate_warn" }
    local exts  = { ".ogg", ".mp3", ".flac", ".wav" }
    for _, name in ipairs(names) do
        for _, ext in ipairs(exts) do
            local path = "assets/sfx/" .. name .. ext
            if love.filesystem.getInfo(path) then
                local ok, src = pcall(love.audio.newSource, path, "static")
                if ok and src then Assets.sounds[name] = src; break end
            end
        end
    end
end

-- ── Public audio API ───────────────────────────────────────────────────────
function Assets.loadSounds()
    pcall(makeSounds)
    pcall(makeAmbience)
    pcall(makeMusic)       -- the synthesized 90s-style tune (the good fit!)
    pcall(makeVoice)
    pcall(makeDockMoods)
    pcall(loadSfxFiles)    -- real-file overrides (e.g. assets/sfx/leave.ogg)
end

-- Start/stop the looping harbor theme (ducks the world music while it plays).
function Assets.startDockMood(mood)
    Assets.stopDockMood()
    if not config.AUDIO_ON then return end
    local key = (mood == "scary") and "dock_scary" or "dock_cosy"
    local s = Assets.sounds[key]
    if s then s:setVolume(0.55); s:play(); Assets._dockMood = s end
    Assets.setMusicVolume(0.12)
end

function Assets.stopDockMood()
    if Assets._dockMood then Assets._dockMood:stop(); Assets._dockMood = nil end
    if config.AUDIO_ON then Assets.setMusicVolume(1.0) end
end

-- Play a recorded voice clip once. Rewinds first so repeat triggers work.
function Assets.playVoice(name)
    if not config.AUDIO_ON then return end
    local src = Assets.voice[name]
    if not src then return end
    src:stop()
    src:setVolume(1.0)        -- voice should be clearly audible over the music
    src:play()
end

-- Play an on-demand voice file from assets/voice/<name>.ogg if it exists.
-- Used by the docking screen for per-town instruction clips you add later.
-- Returns true if a clip was actually played, false if no file is present.
local namedVoiceCache = {}
function Assets.playNamedVoice(name)
    if not config.AUDIO_ON then return false end
    if namedVoiceCache[name] == nil then
        local full = "assets/voice/" .. name .. ".ogg"
        if love.filesystem.getInfo(full) then
            local ok, src = pcall(love.audio.newSource, full, "static")
            namedVoiceCache[name] = ok and src or false
        else
            namedVoiceCache[name] = false
        end
    end
    local src = namedVoiceCache[name]
    if not src then return false end
    src:stop()
    src:setVolume(1.0)
    src:play()
    return true
end

-- Play a one-shot effect. Clones the source so overlapping plays work.
function Assets.playSfx(name, vol)
    if not config.AUDIO_ON then return end
    local src = Assets.sounds[name]
    if not src then return end
    local s = src:clone()
    s:setVolume(vol or config.SFX_VOLUME)   -- optional louder override
    s:play()
end

-- Pirate chase music: loop the ominous drone and duck the cheerful tune while a
-- pirate is hunting; stopChase restores the normal music volume.
function Assets.startChase()
    if not config.AUDIO_ON then return end
    local s = Assets.sounds.chase
    if s and not s:isPlaying() then s:setVolume(0.55); s:play() end
    Assets.setMusicVolume(0.25)
end

function Assets.stopChase()
    if Assets.sounds.chase then Assets.sounds.chase:stop() end
    if config.AUDIO_ON then Assets.setMusicVolume(1.0) end
end

function Assets.startMusic()
    if not config.AUDIO_ON then return end
    if Assets.music and not Assets.music:isPlaying() then
        Assets.music:setVolume(config.MUSIC_VOLUME)
        Assets.music:play()
    end
    if Assets.sounds.ambience and not Assets.sounds.ambience:isPlaying() then
        Assets.sounds.ambience:play()
    end
end

-- Temporarily scale the music + ambience volume (e.g. duck them while the
-- welcome voice is speaking, then restore with scale = 1.0).
function Assets.setMusicVolume(scale)
    if Assets.music then Assets.music:setVolume(config.MUSIC_VOLUME * scale) end
    if Assets.sounds.ambience then Assets.sounds.ambience:setVolume(0.5 * scale) end
end

function Assets.stopMusic()
    if Assets.music then Assets.music:stop() end
    if Assets.sounds.ambience then Assets.sounds.ambience:stop() end
end

-- Called when AUDIO_ON is toggled at runtime.
function Assets.refreshAudio()
    if config.AUDIO_ON then
        Assets.startMusic()
    else
        Assets.stopMusic()
    end
end

return Assets
