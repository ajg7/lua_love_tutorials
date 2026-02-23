--[[
  FREE-LIST OBJECT POOL DEMO
  ==========================
  This demonstrates a memory-efficient particle system using:
  1. Free-list Object Pool: Pre-allocated memory with recycling
  2. SoA (Structure of Arrays) layout: Better cache performance
  3. Fixed timestep: Consistent physics simulation
  4. Interpolation: Smooth rendering between physics steps
  
  What is a Free-list Object Pool?
  --------------------------------
  Instead of creating/destroying particles constantly (slow!),
  we pre-allocate a fixed number of "slots" and reuse them.
  A "free list" tracks which slots are available for use.
  
  In Lua:
  - Tables {} are the main data structure (like arrays/dictionaries)
  - Functions are defined with 'function' keyword
  - ':' syntax (e.g., Pool:init) passes 'self' automatically
--]]

-- Constants
local FIXED_DT = 1/120       -- Physics runs at 120Hz (0.0083 seconds per step)
local MAX_ITERS = 8          -- Maximum physics steps per frame (prevents spiral of death)
local W, H = 800, 600        -- Window width and height
local POOL_SIZE = 400        -- Maximum number of particles that can exist

-- Accumulator for fixed timestep
local acc = 0

--[[
  POOL STRUCTURE (SoA - Structure of Arrays)
  ===========================================
  Instead of: particles[i] = {x=10, y=20, vx=5, ...}  (AoS - Array of Structures)
  We use:     x[i]=10, y[i]=20, vx[i]=5, ...          (SoA - Structure of Arrays)
  
  Why? Better cache locality! CPU loads consecutive memory more efficiently.
  
  FREE LIST STORAGE (the "free" table):
  =====================================
  - free[1..top] stores INDICES of available slots
  - Example: free = {5, 12, 7, 3, ...} means slots 5,12,7,3 are available
  - 'top' is the stack pointer: free[top] is the next available slot
  - When top=0, pool is full (no free slots)
  - This is a STACK (LIFO): we push/pop from the top
--]]
local Pool = {
  -- Particle data arrays (indexed by slot number)
  x = {},        -- Current X position
  y = {},        -- Current Y position
  px = {},       -- Previous X position (for interpolation)
  py = {},       -- Previous Y position (for interpolation)
  vx = {},       -- Velocity X
  vy = {},       -- Velocity Y
  life = {},     -- Remaining lifetime in seconds
  life0 = {},    -- Initial lifetime (for fade calculation)
  
  -- Free-list storage (THIS IS WHERE SLOTS ARE STORED!)
  free = {},     -- Stack of available slot indices: free[1..top]
  top = 0,       -- Stack pointer: how many free slots exist
  size = POOL_SIZE
}

--[[
  INITIALIZATION
  ==============
  Prepares the pool by marking ALL slots as available.
  This is called once at startup.
--]]
function Pool:init()
  -- Loop through all POOL_SIZE slots
  for i = 1, self.size do
    -- Initialize all particle data to zero (inactive state)
    self.x[i], self.y[i] = 0, 0
    self.px[i], self.py[i] = 0, 0
    self.vx[i], self.vy[i] = 0, 0
    self.life[i], self.life0[i] = 0, 0
    
    -- Push this slot index onto the free-list stack
    self.top = self.top + 1
    self.free[self.top] = i    -- free[1]=1, free[2]=2, ..., free[400]=400
  end
  -- After init: top=400, meaning all 400 slots are available
end

--[[
  CREATE (ALLOCATE)
  =================
  O(1) constant-time allocation! Just pop from the free-list stack.
  
  In Lua:
  - 'nil' means "no value" (like null in other languages)
  - Functions can return nil to indicate failure
  - Multiple return values are common: we return the slot index
--]]
function Pool:create(x, y, vx, vy, life)
  -- Check if pool is full (no free slots left)
  if self.top == 0 then 
    return nil    -- Drop this particle request
  end
  
  -- Pop the top index from the free-list stack
  local i = self.free[self.top]    -- Get the index at top of stack
  self.top = self.top - 1          -- Decrease stack pointer
  
  -- Initialize the particle data at slot 'i'
  self.x[i], self.y[i] = x, y
  self.px[i], self.py[i] = x, y    -- Previous position starts same as current
  self.vx[i], self.vy[i] = vx, vy
  self.life[i] = life
  self.life0[i] = life              -- Remember initial lifetime
  
  return i    -- Return the slot index (though we don't use it in this demo)
end

--[[
  UPDATE
  ======
  Physics simulation step - runs at fixed timestep (120Hz).
  
  Key optimization: We check ALL slots but only process active ones.
  Active slots have life > 0. This avoids needing a separate "active list".
  
  When a particle dies (life <= 0), we recycle its slot by pushing
  the index back onto the free-list stack.
--]]
function Pool:update(dt)
  -- Iterate through every slot in the pool
  for i = 1, self.size do
    local L = self.life[i]
    
    -- Only process active particles (life > 0)
    if L > 0 then
      -- Save current position as "previous" for interpolation
      self.px[i], self.py[i] = self.x[i], self.y[i]
      
      -- Apply velocity: new_position = old_position + velocity * time
      self.x[i] = self.x[i] + self.vx[i] * dt
      self.y[i] = self.y[i] + self.vy[i] * dt
      
      -- Decrease lifetime
      L = L - dt
      
      -- Check if particle died this frame
      if L <= 0 then
        self.life[i] = 0              -- Mark as dead
        
        -- RECYCLE: Push slot index back onto free-list stack
        self.top = self.top + 1       -- Increase stack pointer
        self.free[self.top] = i       -- Store index at top of stack
      else
        self.life[i] = L              -- Update remaining life
      end
    end
  end
end

--[[
  DRAW (with Interpolation)
  ==========================
  Renders particles at interpolated positions for smooth visuals.
  
  Why interpolation?
  - Physics runs at 120Hz (every 8.3ms)
  - Display might refresh at 60Hz (every 16.6ms) or 144Hz (every 6.9ms)
  - Without interpolation, movement looks stuttery
  - We interpolate between previous and current position
  
  In LÖVE:
  - love.graphics.setColor(r,g,b,a) sets draw color (0-1 range)
  - love.graphics.rectangle("fill", x, y, w, h) draws a filled rectangle
--]]
function Pool:draw(alpha)
  -- Alpha is the interpolation factor: 0.0 to 1.0
  -- alpha=0 means use previous position, alpha=1 means use current position
  
  for i = 1, self.size do
    local L = self.life[i]
    
    -- Only draw active particles
    if L > 0 then
      -- Interpolate position: lerp = previous + (current - previous) * alpha
      local rx = self.px[i] + (self.x[i] - self.px[i]) * alpha
      local ry = self.py[i] + (self.y[i] - self.py[i]) * alpha
      
      -- Calculate fade: life / life0 gives percentage of life remaining
      local fade = (self.life0[i] > 0) and (L / self.life0[i]) or 0
      
      -- Set color with fade as alpha (white with transparency)
      love.graphics.setColor(1, 1, 1, fade)
      
      -- Draw a 3x3 square
      love.graphics.rectangle("fill", rx, ry, 3, 3)
    end
  end
  
  -- Reset color to opaque white
  love.graphics.setColor(1, 1, 1, 1)
end

-- Create pool instance (in Lua, we can assign tables directly)
local pool = Pool

-- Emitter configuration
local emitter = {
  x = W / 2,       -- Center X
  y = H / 2,       -- Center Y
  burst = 80       -- Number of particles per burst
}

--[[
  EMIT BURST
  ==========
  Creates multiple particles at once, all spawned from emitter position
  with random angles and speeds.
  
  In Lua:
  - '_' is convention for unused variable (the loop counter here)
  - math.pi is π (3.14159...)
  - love.math.random() generates random number between 0 and 1
--]]
local function emitBurst(n)
  for _ = 1, n do
    -- Random angle in radians (0 to 2π for full circle)
    local ang = love.math.random() * 2 * math.pi
    
    -- Random speed between 80 and 220 pixels/second
    local spd = love.math.random(80, 220)
    
    -- Convert polar coordinates (angle, speed) to cartesian (vx, vy)
    -- cos(angle) * speed = horizontal velocity
    -- sin(angle) * speed = vertical velocity
    pool:create(
      emitter.x,              -- spawn X
      emitter.y,              -- spawn Y
      math.cos(ang) * spd,    -- velocity X
      math.sin(ang) * spd,    -- velocity Y
      1.2                     -- lifetime in seconds
    )
  end
end

--[[
  ============================================================================
  LÖVE FRAMEWORK CALLBACKS
  ============================================================================
  LÖVE calls these functions automatically at specific times:
  - love.load() runs once when the program starts
  - love.update(dt) runs every frame before drawing
  - love.draw() runs every frame to render graphics
  - love.keypressed(key) runs when a key is pressed
  - love.mousemoved(x, y) runs when mouse moves
--]]

--[[
  LOVE.LOAD
  =========
  Called once at startup. Use for initialization.
--]]
function love.load()
  -- Set window size
  love.window.setMode(W, H)
  
  -- Set background color (dark blue-gray)
  -- Colors in LÖVE are 0-1 range, not 0-255
  love.graphics.setBackgroundColor(0.08, 0.09, 0.12)
  
  -- Set random seed for reproducible randomness
  love.math.setRandomSeed(1)
  
  -- Initialize the pool (mark all slots as free)
  pool:init()
end

-- Helper function for fixed timestep
local function fixedUpdate()
  pool:update(FIXED_DT)
end

--[[
  LOVE.UPDATE
  ===========
  Called every frame with 'dt' (delta time) = seconds since last frame.
  
  FIXED TIMESTEP PATTERN:
  -----------------------
  Problem: Frame rate varies (60fps, 144fps, etc.) making physics inconsistent
  Solution: Accumulate time and run physics at fixed intervals (120Hz)
  
  How it works:
  1. Add frame time to accumulator
  2. While accumulator >= fixed timestep, run one physics step
  3. Subtract fixed timestep from accumulator
  4. Remaining accumulator time is used for interpolation in draw()
--]]
function love.update(dt)
  -- Cap delta time to prevent "spiral of death"
  -- If frame took >100ms, pretend it was 100ms
  dt = math.min(dt, 0.10)
  
  -- Add this frame's time to accumulator
  acc = acc + dt
  
  -- Run fixed timestep updates
  local it = 0    -- Iteration counter
  while acc >= FIXED_DT and it < MAX_ITERS do
    fixedUpdate()               -- Run one physics step
    acc = acc - FIXED_DT        -- Consume time from accumulator
    it = it + 1                 -- Count iterations
  end
  
  -- Safety: if we hit max iterations, reset accumulator
  -- This prevents infinite loops if physics takes too long
  if it == MAX_ITERS then
    acc = 0
  end
end

--[[
  LOVE.DRAW
  =========
  Called every frame to render graphics.
  Calculates interpolation alpha and draws particles smoothly.
--]]
function love.draw()
  -- Calculate interpolation factor: how far between physics steps are we?
  -- acc / FIXED_DT gives 0.0 (just after physics) to 1.0 (just before next physics)
  local alpha = acc / FIXED_DT
  if alpha > 1 then
    alpha = 1    -- Clamp to 1.0 (shouldn't happen, but safety first)
  end
  
  -- Draw particles with interpolation
  pool:draw(alpha)
  
  -- Display UI text
  -- love.graphics.print(text, x, y) draws text at position
  love.graphics.print("Free slots: " .. pool.top .. " / " .. pool.size, 10, 10)
  love.graphics.print("SPACE = emit | drag mouse moves emitter", 10, 28)
end

--[[
  LOVE.KEYPRESSED
  ===============
  Called when a key is pressed.
  
  In Lua: 'k' parameter is a string like "space", "escape", "a", etc.
--]]
function love.keypressed(k)
  if k == "space" then
    emitBurst(emitter.burst)    -- Spawn 80 particles
  end
  
  if k == "escape" then
    love.event.quit()           -- Exit the program
  end
end

--[[
  LOVE.MOUSEMOVED
  ===============
  Called when mouse moves. x and y are the new mouse coordinates.
  
  In Lua: Multiple assignments in one line: var1, var2 = val1, val2
--]]
function love.mousemoved(x, y)
  emitter.x, emitter.y = x, y   -- Update emitter position to mouse
end
