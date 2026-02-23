--[[
  main.lua — Service Locator (Beginner) + tiny audio service

  What this file shows
  - The "Service Locator" pattern: game code calls a global Locator to get
    services (here: audio) without caring which concrete implementation it is.
  - A Null object implementation for audio so the rest of the game can call
    audio functions safely even when sound is disabled.
  - A fixed-timestep update loop plus render-time interpolation for smooth
    motion, similar to the other examples in this repo.

  Notes for LÖVE newcomers
  - LÖVE calls love.load once, love.update(dt) every frame with the time in
    seconds since last frame, and love.draw every frame to render.
  - LÖVE already handles double buffering internally: love.draw renders to a
    back buffer which is swapped to the screen. Our interpolation is only for
    smoother motion, not manual buffer management.
]]

local FIXED_DT, MAX_ITERS = 1/120, 8
local accumulator = 0
local WINDOW_WIDTH, WINDOW_HEIGHT = 800, 600

-- Simple service locator with just one service slot: audio.
local Locator = { _audio = nil }
function Locator.provideAudio(service) Locator._audio = service end
function Locator.getAudio() return Locator._audio end

-- NullAudio implements the same API as the real audio service but does nothing.
-- This is safe to call from anywhere without checking for nil.
local NullAudio = {}
function NullAudio:play(name) end
function NullAudio:setVolume(volume) end
function NullAudio:stopAll() end

-- ========== LoveAudio (real) ==========
local function makeSine(seconds, hz, rate)
  rate = rate or 44100
  local sd = love.sound.newSoundData(math.floor(seconds * rate), rate, 16, 1)
  local twoPiF = 2 * math.pi * hz
  for i = 0, sd:getSampleCount()-1 do
    local t = i / rate
    sd:setSample(i, math.sin(twoPiF * t) * 0.5)
  end
  return sd
end

-- LoveAudio is the real implementation that uses love.audio.
local LoveAudio = { volume = 1.0, sources = {} }
function LoveAudio:init()
  -- preload a short “beep” and keep a cloneable Source
  local sd = makeSine(0.12, 880)
  self.sources.beep = love.audio.newSource(sd, "static")
  self.sources.beep:setVolume(self.volume)
end
function LoveAudio:setVolume(volume)
  self.volume = math.max(0, math.min(1, volume))
  if self.sources.beep then self.sources.beep:setVolume(self.volume) end
end
function LoveAudio:play(name)
  local base = self.sources[name]
  if not base then return end
  local s = base:clone()
  s:setVolume(self.volume)
  s:play()
end
function LoveAudio:stopAll()
  love.audio.stop()
end

-- ========== Demo world: a bouncing box that pings on walls ==========
local box = {
  x = 100, y = 120,
  px = 100, py = 120, -- previous position (for interpolation)
  w = 40, h = 28,
  vx = 160, vy = 90,
}

local function fixedUpdate()
  -- Snapshot current position for render interpolation
  box.px, box.py = box.x, box.y
  -- Integrate velocity using the fixed timestep
  box.x = box.x + box.vx * FIXED_DT
  box.y = box.y + box.vy * FIXED_DT

  local hit = false
  if box.x < 0 then box.x = 0; box.vx = math.abs(box.vx); hit = true end
  if box.x + box.w > WINDOW_WIDTH then box.x = WINDOW_WIDTH - box.w; box.vx = -math.abs(box.vx); hit = true end
  if box.y < 0 then box.y = 0; box.vy = math.abs(box.vy); hit = true end
  if box.y + box.h > WINDOW_HEIGHT then box.y = WINDOW_HEIGHT - box.h; box.vy = -math.abs(box.vy); hit = true end

  if hit then Locator.getAudio():play("beep") end
end

function love.load()
  love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
  love.graphics.setBackgroundColor(0.08,0.09,0.12)

  -- provide real audio by default
  Locator.provideAudio(LoveAudio)
  LoveAudio:init()
end

function love.update(dt)
  dt = math.min(dt, 0.10)
  accumulator = accumulator + dt
  local iterations = 0
  while accumulator >= FIXED_DT and iterations < MAX_ITERS do
    fixedUpdate()
    accumulator = accumulator - FIXED_DT
    iterations = iterations + 1
  end
  if iterations == MAX_ITERS then accumulator = 0 end
end

function love.draw()
  -- Interpolation factor (0..1): how far we are to the next physics step.
  local alpha = math.min(1, accumulator / FIXED_DT)
  local renderX = box.px + (box.x - box.px) * alpha
  local renderY = box.py + (box.y - box.py) * alpha
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle("fill", renderX, renderY, box.w, box.h)

  local usingNull = (Locator.getAudio() == NullAudio)
  local volume = (Locator.getAudio().volume or 0)
  love.graphics.print("Service Locator: Audio", 10, 10)
  love.graphics.print("SPACE: beep | M: mute/unmute | V/B: vol -/+", 10, 28)
  love.graphics.print(("Audio: %s  Volume: %.2f"):format(usingNull and "Null" or "Real", volume), 10, 46)
end

function love.keypressed(k)
  if k == "space" then
    Locator.getAudio():play("beep")
  elseif k == "m" then
    if Locator.getAudio() == NullAudio then
      Locator.provideAudio(LoveAudio); LoveAudio:setVolume(LoveAudio.volume or 1)
    else
      Locator.provideAudio(NullAudio)
    end
  elseif k == "v" then
    if Locator.getAudio().setVolume then Locator.getAudio():setVolume((Locator.getAudio().volume or 1) - 0.1) end
  elseif k == "b" then
    if Locator.getAudio().setVolume then Locator.getAudio():setVolume((Locator.getAudio().volume or 1) + 0.1) end
  elseif k == "escape" then
    love.event.quit()
  end
end
