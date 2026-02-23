-- Fixed timestep for consistent physics (120 FPS) and maximum iterations to prevent spiral of death
local FIXED_DT, MAX_ITERS = 1/120, 8
-- Accumulator for fixed timestep implementation
local acc = 0
-- Window dimensions
local W, H = 800, 600
-- Maximum number of particles in our object pool
local POOL_SIZE = 200

-- Particle class definition using Lua's metatable system
-- In Lua, we simulate classes using tables and metatables
local Particle = {}
Particle.__index = Particle  -- This makes Particle act like a class prototype
-- Constructor function - creates a new particle instance
-- setmetatable links this table to the Particle class
function Particle:new()
  return setmetatable({
    x = 0,      -- current x position
    y = 0,      -- current y position
    px = 0,     -- previous x position (for interpolation)
    py = 0,     -- previous y position (for interpolation)
    vx = 0,     -- velocity in x direction
    vy = 0,     -- velocity in y direction
    life = 0    -- remaining lifetime in seconds
  }, self)
end

-- Initialize/reset a particle with new values (used when recycling from pool)
-- This is separate from :new() to allow reusing existing particle objects
function Particle:init(x, y, vx, vy, life) 
  self.x, self.y = x, y        -- set current position
  self.vx, self.vy = vx, vy    -- set velocity
  self.px, self.py = x, y      -- set previous position to current (no interpolation on first frame)
  self.life = life             -- set lifetime
end

-- Update particle physics and lifetime
-- dt = delta time (time since last update in seconds)
function Particle:update(dt)
  if self.life <= 0 then return end  -- skip if particle is dead
  
  -- Store current position as previous position (for smooth interpolation)
  self.px, self.py = self.x, self.y
  
  -- Update position using velocity (basic physics integration)
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
  
  -- Decrease remaining lifetime
  self.life = self.life - dt
end

-- Draw the particle with interpolation for smooth movement
-- alpha = interpolation factor between previous and current position (0.0 to 1.0)
function Particle:draw(alpha)
  if self.life <= 0 then return end  -- skip if particle is dead
  
  -- Interpolate between previous and current position for smooth rendering
  -- This prevents stuttering when render rate differs from update rate
  local rx = self.px + (self.x - self.px) * alpha
  local ry = self.py + (self.y - self.py) * alpha
  
  -- Draw a small 3x3 white rectangle at interpolated position
  love.graphics.rectangle("fill", rx, ry, 3, 3)
end

-- Check if particle is currently active/alive
function Particle:inUse() return self.life > 0 end

-- Object Pool - pre-allocates particles to avoid garbage collection during gameplay
-- This improves performance by reusing objects instead of creating/destroying them
local Pool = { items = {}, size = POOL_SIZE }

-- Initialize the pool by creating all particle objects upfront
function Pool:init() 
  for i = 1, self.size do
    self.items[i] = Particle:new()  -- create inactive particles
  end
end

-- Find an unused particle and activate it with new parameters
-- Returns the particle if successful, nil if pool is full
function Pool:create(x, y, vx, vy, life) 
  for i = 1, self.size do
    local p = self.items[i]
    if not p:inUse() then           -- found an inactive particle
      p:init(x, y, vx, vy, life)   -- reset it with new values
      return p                     -- return the activated particle
    end
  end
  return nil  -- no free particles available (pool exhausted)
end

-- Update all particles in the pool (both active and inactive)
function Pool:update(dt)
  for i = 1,self.size do self.items[i]:update(dt) end
end

-- Draw all particles in the pool (inactive particles will skip themselves)
function Pool:draw(alpha)
  for i = 1,self.size do self.items[i]:draw(alpha) end
end

-- Create instances
local pool = Pool
local emitter = { x = W/2, y = H/2, burst = 60 }  -- particle emitter at screen center

-- LÖVE2D callback: called once at the start of the program
function love.load()
  love.window.setMode(W, H)                        -- set window size
  love.graphics.setBackgroundColor(0.08,0.09,0.12) -- dark blue background
  pool:init()                                      -- initialize the particle pool
end

-- Create a burst of n particles in random directions
local function emitBurst(n)
  for i = 1, n do
    -- Generate random direction (0 to 2π radians = full circle)
    local angle = love.math.random() * 2 * math.pi
    -- Random speed between 80 and 220 pixels per second
    local speed = love.math.random(80, 220)
    -- Convert polar coordinates (angle, speed) to cartesian velocity (vx, vy)
    local vx = math.cos(angle) * speed
    local vy = math.sin(angle) * speed
    -- Create particle at emitter position with calculated velocity and 2 second lifetime
    pool:create(emitter.x, emitter.y, vx, vy, 2)
  end
end

-- Fixed timestep update function - called at consistent intervals
local function fixedUpdate()
  pool:update(FIXED_DT)  -- update particles with fixed delta time
end

-- LÖVE2D callback: called every frame with variable timestep
function love.update(dt)
  dt = math.min(dt, 0.10)            -- clamp frame spikes to max 100ms (prevents large jumps)
  acc = acc + dt                     -- accumulate time
  local it = 0                       -- iteration counter
  
  -- Run fixed updates until we've caught up with real time
  while acc >= FIXED_DT and it < MAX_ITERS do
    fixedUpdate()                    -- run one fixed timestep
    acc, it = acc - FIXED_DT, it + 1 -- subtract fixed time and increment counter
  end
  
  -- "Spiral of death" protection - if we can't catch up, reset accumulator
  if it == MAX_ITERS then acc = 0 end -- panic dump
end

-- LÖVE2D callback: called every frame to render graphics
function love.draw()
  -- Calculate interpolation alpha for smooth rendering between fixed updates
  local a = acc / FIXED_DT; if a > 1 then a = 1 end  -- clamp alpha to [0,1]
  
  love.graphics.setColor(1,1,1)  -- set drawing color to white
  pool:draw(a)                   -- draw all particles with interpolation
  
  -- Draw UI text
  love.graphics.print("Press SPACE to emit, drag mouse to move emitter", 10, 10)
  love.graphics.print("Active (approx): "..countActive(pool), 10, 30)
end

-- Count how many particles are currently active (for display purposes)
function countActive(p)
  local n = 0
  for i = 1,p.size do 
    if p.items[i]:inUse() then n = n + 1 end 
  end
  return n
end

-- LÖVE2D callback: called when a key is pressed
function love.keypressed(k)
  if k == "space" then emitBurst(emitter.burst) end  -- spacebar creates particle burst
  if k == "escape" then love.event.quit() end        -- escape key exits program
end

-- LÖVE2D callback: called when mouse moves
-- Updates emitter position to follow mouse cursor
function love.mousemoved(x,y) emitter.x, emitter.y = x,y end
