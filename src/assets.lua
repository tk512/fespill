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

-- ── Public audio API ───────────────────────────────────────────────────────
function Assets.loadSounds()
    pcall(makeSounds)
    pcall(makeAmbience)
    pcall(makeMusic)
    pcall(makeVoice)
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
function Assets.playSfx(name)
    if not config.AUDIO_ON then return end
    local src = Assets.sounds[name]
    if not src then return end
    local s = src:clone()
    s:setVolume(config.SFX_VOLUME)
    s:play()
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
