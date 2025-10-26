--[[
    Data Locality Demonstration: Array of Structures (AoS) vs Structure of Arrays (SoA)
    
    This example demonstrates two different ways to organize particle data in memory:
    - AoS: Each particle is a table containing all its properties
    - SoA: Properties are stored in separate arrays, indexed by particle ID
    
    In Lua, SoA can be more cache-friendly for operations that access the same
    property across many particles, while AoS keeps related data together.
--]]

-- Game timing constants
local FIXED_DT = 1/120      -- Fixed timestep: 120 updates per second (in seconds)
local MAX_ITERS = 8         -- Maximum update iterations per frame to prevent spiral of death
local acc = 0               -- Accumulator for fixed timestep implementation

-- Window dimensions
local W, H = 800, 600       -- Width and Height of the game window

-- Simulation parameters
local N = 1500              -- Number of particles in the simulation
local layout = "AoS"        -- Current data layout ("AoS" or "SoA")

-- ===============================================================================
-- AoS: Array of Structures Implementation
-- ===============================================================================
--[[
    In AoS, each particle is represented as a table (Lua's equivalent of a struct/object)
    containing all of its properties. This keeps related data together in memory.
    
    Pros: Good for operations that need multiple properties of the same particle
    Cons: May have poor cache performance when processing the same property across many particles
--]]

local AoS = {}

-- Initialize the AoS particle system with n particles
function AoS:init(n)
    self.p = {}  -- Array to hold all particle tables
    
    for i = 1, n do
        -- Generate random angle (0 to 2π radians) for initial velocity direction
        local angle = love.math.random() * 2 * math.pi
        -- Generate random speed between 80 and 220 pixels per second
        local speed = love.math.random(80, 220)
        
        -- Create a new particle table with all properties
        self.p[i] = {
            -- Current position
            x = W / 2,
            y = H / 2,
            
            -- Previous position (for interpolation)
            px = W / 2,
            py = H / 2,
            
            -- Velocity components (pixels per second)
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            
            -- Lifetime: random between 0.5-2.0 seconds
            life = love.math.random() * 1.5 + 0.5,
            life0 = 0  -- Will store initial lifetime for alpha calculation
        }
        
        -- Store the initial lifetime for fade-out effect
        self.p[i].life0 = self.p[i].life
    end
end

-- Update all particles in the AoS system
function AoS:update(dt)
    -- Iterate through all particles
    for i = 1, #self.p do
        local particle = self.p[i]  -- Get reference to current particle
        
        -- Only update particles that are still alive
        if particle.life > 0 then
            -- Store current position as previous position (for interpolation)
            particle.px, particle.py = particle.x, particle.y
            
            -- Update position based on velocity and delta time
            -- Physics: new_position = old_position + velocity * time
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt
            
            -- Decrease remaining lifetime
            particle.life = particle.life - dt
        end
    end
end

-- Draw all particles in the AoS system with interpolation
function AoS:draw(alpha)
    for i = 1, #self.p do
        local particle = self.p[i]
        
        -- Only draw particles that are still alive
        if particle.life > 0 then
            -- Interpolate position between previous and current for smooth rendering
            -- This provides smooth visuals even with fixed timestep updates
            local render_x = particle.px + (particle.x - particle.px) * alpha
            local render_y = particle.py + (particle.y - particle.py) * alpha
            
            -- Calculate alpha (transparency) based on remaining life
            -- Particles fade out as they die: 1.0 = fully opaque, 0.0 = transparent
            local fade_alpha = particle.life / particle.life0
            
            -- Set color to white with calculated transparency
            -- In LOVE2D: setColor(red, green, blue, alpha) with values 0.0-1.0
            love.graphics.setColor(1, 1, 1, fade_alpha)
            
            -- Draw a small 3x3 pixel rectangle representing the particle
            love.graphics.rectangle("fill", render_x, render_y, 3, 3)
        end
    end
end

-- ===============================================================================
-- SoA: Structure of Arrays Implementation
-- ===============================================================================
--[[
    In SoA, each property is stored in its own array, and particles are identified by index.
    All x positions are together, all y positions are together, etc.
    
    Pros: Better cache performance when processing the same property across many particles
    Cons: May require more memory accesses when working with multiple properties of one particle
--]]

local SoA = {}

-- Initialize the SoA particle system with n particles
function SoA:init(n)
    -- Create separate arrays for each particle property
    -- This keeps similar data types together in memory
    self.x = {}       -- Current X positions
    self.y = {}       -- Current Y positions
    self.px = {}      -- Previous X positions (for interpolation)
    self.py = {}      -- Previous Y positions (for interpolation)
    self.vx = {}      -- X velocity components
    self.vy = {}      -- Y velocity components
    self.life = {}    -- Current lifetime remaining
    self.life0 = {}   -- Initial lifetime (for fade calculation)
    
    -- Initialize all particles
    for i = 1, n do
        -- Generate random angle (0 to 2π radians) for initial velocity direction
        local angle = love.math.random() * 2 * math.pi
        -- Generate random speed between 80 and 220 pixels per second
        local speed = love.math.random(80, 220)
        
        -- Set initial positions (center of screen)
        self.x[i], self.y[i] = W / 2, H / 2
        self.px[i], self.py[i] = W / 2, H / 2
        
        -- Calculate velocity components from angle and speed
        self.vx[i], self.vy[i] = math.cos(angle) * speed, math.sin(angle) * speed
        
        -- Set random lifetime between 0.5-2.0 seconds
        self.life[i] = love.math.random() * 1.5 + 0.5
        self.life0[i] = self.life[i]  -- Store initial lifetime
    end
end
-- Update all particles in the SoA system
function SoA:update(dt)
    -- Iterate through all particles by index
    for i = 1, #self.x do
        local life = self.life[i]  -- Cache current life value
        
        -- Only update particles that are still alive
        if life > 0 then
            -- Store current position as previous position (for interpolation)
            self.px[i], self.py[i] = self.x[i], self.y[i]
            
            -- Update position based on velocity and delta time
            -- Notice how we access each array separately by the same index
            self.x[i] = self.x[i] + self.vx[i] * dt
            self.y[i] = self.y[i] + self.vy[i] * dt
            
            -- Decrease remaining lifetime
            self.life[i] = life - dt
        end
    end
end
-- Draw all particles in the SoA system with interpolation
function SoA:draw(alpha)
    for i = 1, #self.x do
        -- Only draw particles that are still alive
        if self.life[i] > 0 then
            -- Interpolate position between previous and current for smooth rendering
            -- Each property is accessed from its own array using the same index
            local render_x = self.px[i] + (self.x[i] - self.px[i]) * alpha
            local render_y = self.py[i] + (self.y[i] - self.py[i]) * alpha
            
            -- Calculate alpha (transparency) based on remaining life ratio
            local fade_alpha = self.life[i] / self.life0[i]
            
            -- Set color to white with calculated transparency
            love.graphics.setColor(1, 1, 1, fade_alpha)
            
            -- Draw a small 3x3 pixel rectangle representing the particle
            love.graphics.rectangle("fill", render_x, render_y, 3, 3)
        end
    end
end

-- ===============================================================================
-- Main Game Logic and LOVE2D Callbacks
-- ===============================================================================

-- Currently active particle system (starts with AoS)
local active = AoS

--[[
    love.load() - Called once at the start of the game
    This is where we initialize everything that needs to be set up once
--]]
function love.load()
    -- Set the window size to our defined width and height
    love.window.setMode(W, H)
    
    -- Set background color to a dark blue-grey
    -- Colors in LOVE2D are 0.0-1.0, so (0.08, 0.09, 0.12) is a dark color
    love.graphics.setBackgroundColor(0.08, 0.09, 0.12)
    
    -- Initialize both particle systems with N particles
    AoS:init(N)
    SoA:init(N)
end
-- Fixed timestep update function
-- This ensures consistent physics regardless of framerate
local function fixedUpdate()
    active:update(FIXED_DT)
end

--[[
    love.update(dt) - Called every frame with delta time
    dt = time since last frame in seconds
    
    This implements a fixed timestep game loop to ensure consistent physics.
    Instead of updating with variable dt, we accumulate time and update in fixed chunks.
--]]
function love.update(dt)
    -- Clamp delta time to prevent large jumps (e.g., when debugging or lagging)
    -- Maximum 0.1 seconds (10 FPS) to prevent "spiral of death"
    dt = math.min(dt, 0.10)
    
    -- Add this frame's time to our accumulator
    acc = acc + dt
    
    local iterations = 0
    
    -- While we have enough accumulated time for a fixed update
    while acc >= FIXED_DT and iterations < MAX_ITERS do
        -- Perform one fixed timestep update
        fixedUpdate()
        
        -- Subtract the fixed timestep from accumulator
        acc = acc - FIXED_DT
        iterations = iterations + 1
    end
    
    -- Safety check: if we hit max iterations, reset accumulator
    -- This prevents infinite loops in extreme lag situations
    if iterations == MAX_ITERS then 
        acc = 0 
    end
end
--[[
    love.draw() - Called every frame to render graphics
    This is where all drawing/rendering happens
--]]
function love.draw()
    -- Calculate interpolation alpha for smooth rendering
    -- This determines how far between the last and next fixed update we are
    local alpha = acc / FIXED_DT
    if alpha > 1 then alpha = 1 end  -- Clamp to maximum of 1.0
    
    -- Set drawing color to white (no tint)
    love.graphics.setColor(1, 1, 1)
    
    -- Draw the currently active particle system with interpolation
    active:draw(alpha)
    
    -- Reset color to full white with full opacity for text
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw informational text at top-left of screen
    love.graphics.print("Layout: " .. layout .. "  (TAB to toggle)  N=" .. N, 10, 10)
end
--[[
    love.keypressed(key) - Called when a key is pressed
    key = string representation of the key that was pressed
--]]
function love.keypressed(key)
    if key == "tab" then
        -- Toggle between AoS and SoA layouts
        -- Lua's ternary-like operator: condition and value1 or value2
        layout = (layout == "AoS") and "SoA" or "AoS"
        active = (layout == "AoS") and AoS or SoA
        
    elseif key == "escape" then
        -- Quit the game when Escape is pressed
        love.event.quit()
    end
end
