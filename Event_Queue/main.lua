

--[[
Event Queue System Demo - LÖVE2D
=====================================

This demo showcases an event-driven architecture using an event queue pattern.
Instead of directly modifying game state when input occurs, we post "events" 
to a central queue and process them later during the game update loop.

Key Concepts Demonstrated:
--------------------------
1. EVENT QUEUE: Central system that stores and processes game events
2. FIXED TIMESTEP: Game logic runs at consistent intervals regardless of frame rate
3. COMPONENT SYSTEM: Entities have swappable behavior components (Patroller, Drifter, Orbiter)
4. INTERPOLATION: Smooth rendering between fixed timestep updates
5. DECOUPLED INPUT: Input handling is separated from game logic via events

Architecture Overview:
---------------------
- Input (keyboard) → Posts Events → Event Queue → Processes Events → Updates Game State
- This prevents timing issues and makes the code more modular and testable

Files Structure:
- Entity: Represents moveable squares with position, color, and behavior
- Behaviors: PatrollerBehavior, DrifterBehavior, OrbiterBehavior (movement patterns)
- EventBus: Central event management system with queue and handlers
- InputHandler: Converts keyboard input into events
- LÖVE2D Callbacks: love.load(), love.update(), love.draw(), love.keypressed()

Benefits of Event-Driven Design:
- Clean separation between input, logic, and rendering
- Easy to add new event types and handlers
- Prevents cascading updates and timing issues
- Makes testing and debugging easier
- Allows for event logging, replay, and undo systems
--]]

-- Game configuration constants
local FIXED_TIMESTEP = 1/120  -- Update game logic 120 times per second for smooth movement
local MAX_ITERATIONS = 5      -- Prevent infinite loops if frame rate drops too low
local SCREEN_WIDTH = 800
local SCREEN_HEIGHT = 600
local SQUARE_SIZE = 20        -- Size of each entity square in pixels
local MAX_EVENTS_PER_FRAME = 16  -- Process at most 16 events per frame to prevent lag

-- Global game state variables
local entities = {}           -- Table storing all game entities (squares that move around)
local accumulator = 0         -- Tracks leftover time for fixed timestep updates
local currentTime = 0         -- Current game time for frame calculations
local score = 0              -- Player's current score
local isProcessingEvents = false  -- Flag to prevent recursive event posting

-- Forward declarations for classes (Lua doesn't require this, but helps readability)
local Entity, PatrollerBehavior, DrifterBehavior, OrbiterBehavior
local eventBus = {}           -- Will hold our central event management system

-- Entity Class - Represents a moveable square on screen
-- In Lua, we simulate classes using tables and metatables
Entity = {}
Entity.__index = Entity  -- This makes Entity work like a class template

-- Constructor function - creates a new entity instance
function Entity:new(x, y, behavior) 
  local entity = {
    x = x or 0,           -- Current X position
    y = y or 0,           -- Current Y position
    prevX = x or 0,       -- Previous X position (for smooth interpolation)
    prevY = y or 0,       -- Previous Y position (for smooth interpolation)
    active = true,        -- Whether this entity should be updated/drawn
    behavior = behavior,  -- Behavior object that controls how this entity moves
    color = {love.math.random(), love.math.random(), love.math.random()}  -- Random RGB color
  }

  setmetatable(entity, self)  -- Makes this table inherit from Entity class
  return entity
end

-- Update function - called every fixed timestep to update entity logic
function Entity:update(dt)
    if not self.active then return end  -- Skip inactive entities
    
    -- Store previous position for smooth rendering between updates
    self.prevX = self.x
    self.prevY = self.y

    -- Let the behavior component handle movement logic
    if self.behavior and self.behavior.update then
        self.behavior:update(self, dt)  -- Pass this entity and delta time to behavior
    end
end

-- Render function - draws the entity with smooth interpolation
function Entity:render(alpha)
    if not self.active then return end  -- Don't draw inactive entities
    
    -- Interpolate between previous and current position for smooth movement
    -- Alpha is how far between the last update and next update we are (0.0 to 1.0)
    local renderX = self.prevX + (self.x - self.prevX) * alpha
    local renderY = self.prevY + (self.y - self.prevY) * alpha

    love.graphics.setColor(self.color)  -- Set drawing color to entity's color
    love.graphics.rectangle("fill", renderX, renderY, SQUARE_SIZE, SQUARE_SIZE)
end

-- Toggle whether this entity is active (used by events)
function Entity:toggleActive()
    self.active = not self.active
end

-- PatrollerBehavior Class - Makes entities move back and forth horizontally
-- This is a component that can be attached to entities to give them specific movement
PatrollerBehavior = {}
PatrollerBehavior.__index = PatrollerBehavior

-- Constructor - creates a new patroller behavior
function PatrollerBehavior:new(speed, minX, maxX)
    local behavior = {
        speed = speed or 100,                    -- Pixels per second movement speed
        minX = minX or 50,                      -- Left boundary for patrolling
        maxX = maxX or SCREEN_WIDTH - 50,       -- Right boundary for patrolling
        direction = 1                           -- 1 = moving right, -1 = moving left
    }
    setmetatable(behavior, self)
    return behavior
end

-- Update function - called every frame to move the entity
function PatrollerBehavior:update(entity, dt)
    -- Move entity horizontally based on speed, direction, and time passed
    entity.x = entity.x + self.speed * self.direction * dt
    
    -- Check if we've hit a boundary and need to turn around
    if entity.x <= self.minX or entity.x >= self.maxX then
        self.direction = -self.direction  -- Reverse direction
        -- Clamp position to stay within boundaries
        entity.x = math.max(self.minX, math.min(self.maxX, entity.x))
    end
end

-- DrifterBehavior Class - Makes entities wander randomly around the screen
-- These entities change direction randomly and wrap around screen edges
DrifterBehavior = {}
DrifterBehavior.__index = DrifterBehavior

-- Constructor - creates a new drifter behavior
function DrifterBehavior:new(speed)
    local behavior = {
        speed = speed or 80,                        -- Base movement speed in pixels/second
        vx = love.math.random(-1, 1),              -- X velocity (-1 to 1, random direction)
        vy = love.math.random(-1, 1),              -- Y velocity (-1 to 1, random direction)
        changeTimer = 0,                           -- Tracks time since last direction change
        changeInterval = love.math.random(1, 3)    -- How often to change direction (1-3 seconds)
    }
    setmetatable(behavior, self)
    return behavior
end

-- Update function - moves entity and occasionally changes direction
function DrifterBehavior:update(entity, dt)
    -- Move entity based on current velocity
    entity.x = entity.x + self.vx * self.speed * dt
    entity.y = entity.y + self.vy * self.speed * dt
    
    -- Wrap around screen edges (teleport to opposite side when going off screen)
    if entity.x < 0 then entity.x = SCREEN_WIDTH end
    if entity.x > SCREEN_WIDTH then entity.x = 0 end
    if entity.y < 0 then entity.y = SCREEN_HEIGHT end
    if entity.y > SCREEN_HEIGHT then entity.y = 0 end
    
    -- Update timer and check if it's time to change direction
    self.changeTimer = self.changeTimer + dt
    if self.changeTimer >= self.changeInterval then
        -- Pick new random direction
        self.vx = love.math.random(-1, 1)
        self.vy = love.math.random(-1, 1)
        self.changeTimer = 0  -- Reset timer
        self.changeInterval = love.math.random(1, 3)  -- Set new random interval
    end
end

-- OrbiterBehavior Class - Makes entities move in circles around a center point
-- Uses trigonometry (sin/cos) to create smooth circular motion
OrbiterBehavior = {}
OrbiterBehavior.__index = OrbiterBehavior

-- Constructor - creates a new orbiter behavior
function OrbiterBehavior:new(centerX, centerY, radius, speed)
    local behavior = {
        centerX = centerX or SCREEN_WIDTH/2,       -- X coordinate of circle center
        centerY = centerY or SCREEN_HEIGHT/2,      -- Y coordinate of circle center
        radius = radius or 100,                    -- Distance from center (circle size)
        speed = speed or 2,                        -- How fast to rotate (radians per second)
        angle = love.math.random() * math.pi * 2   -- Starting angle (random position on circle)
    }
    setmetatable(behavior, self)
    return behavior
end

-- Update function - moves entity in a circle using trigonometry
function OrbiterBehavior:update(entity, dt)
    -- Increment angle based on speed and time passed
    self.angle = self.angle + self.speed * dt
    
    -- Calculate position on circle using cos/sin
    -- cos gives us X offset from center, sin gives us Y offset from center
    entity.x = self.centerX + math.cos(self.angle) * self.radius
    entity.y = self.centerY + math.sin(self.angle) * self.radius
end

-- EventBus Class - Central event management system
-- This implements an event queue pattern where actions are posted as events
-- and processed later, which decouples input handling from game logic
local EventBus = {
    queue = {},      -- Array of pending events to process
    eventCount = 0   -- Total number of events posted (for debugging)
}
EventBus.__index = EventBus

-- Constructor - creates a new event bus instance
function EventBus:new()
    local bus = {
        queue = {},
        eventCount = 0
    }
    setmetatable(bus, self)
    return bus
end

-- Event-Driven Architecture Explanation:
-- Instead of directly modifying game state when input occurs, we "post" events
-- to a queue and process them later. This creates clean separation between
-- input handling, game logic, and prevents timing issues.


-- Post an event to the queue for later processing
-- This is the main way to request actions in our event-driven system
function EventBus:push(eventType, data)
    -- Guard against nested posts during event handling
    -- This prevents infinite loops where handling one event posts another event
    if isProcessingEvents then
        print("Warning: Attempted to post event during processing - " .. eventType)
        return false
    end
    
    -- Create event object with type, data, and timestamp
    local event = {
        type = eventType,                    -- String describing what action to take
        data = data or {},                   -- Additional parameters for the event
        timestamp = love.timer.getTime()     -- When this event was created
    }
    
    -- Add event to the end of the queue
    table.insert(self.queue, event)
    self.eventCount = self.eventCount + 1
    return true
end

-- Process events from the queue - called once per frame
-- This is where queued events actually get handled and affect the game
function EventBus:processEvents()
    if #self.queue == 0 then return end  -- Nothing to process
    
    isProcessingEvents = true  -- Set flag to prevent recursive event posting
    local eventsProcessed = 0
    
    -- Process up to MAX_EVENTS_PER_FRAME to prevent frame rate hitches
    -- If we have 1000 events queued, we don't want to process them all in one frame
    while #self.queue > 0 and eventsProcessed < MAX_EVENTS_PER_FRAME do
        local event = table.remove(self.queue, 1)  -- Remove first event from queue
        self:handleEvent(event)                     -- Process this specific event
        eventsProcessed = eventsProcessed + 1
    end
    
    isProcessingEvents = false  -- Clear flag - safe to post events again
end

-- Route events to their specific handler functions
-- This is like a big switch statement that decides what to do based on event type
function EventBus:handleEvent(event)
    if event.type == "toggle_one" then
        self:handleToggleOne(event.data)
    elseif event.type == "toggle_all" then
        self:handleToggleAll(event.data)
    elseif event.type == "spawn_drifter" then
        self:handleSpawnDrifter(event.data)
    elseif event.type == "score_add" then
        self:handleScoreAdd(event.data)
    else
        print("Unknown event type: " .. event.type)
    end
end

-- Event Handler: Toggle one entity's active state
function EventBus:handleToggleOne(data)
    local targetId = data.entityId
    if targetId and entities[targetId] then
        -- Toggle specific entity if ID was provided
        entities[targetId]:toggleActive()
        -- Post score event for successful toggle
        if not isProcessingEvents then
            eventBus:push("score_add", {points = 10})
        else
            score = score + 10 -- Direct update during processing to avoid recursion
        end
    else
        -- Toggle random entity if no specific ID provided
        if #entities > 0 then
            local randomIndex = love.math.random(1, #entities)
            entities[randomIndex]:toggleActive()
            if not isProcessingEvents then
                eventBus:push("score_add", {points = 5})
            else
                score = score + 5
            end
        end
    end
end

-- Event Handler: Toggle all entities at once
function EventBus:handleToggleAll(data)
    local newState = data.active
    if newState == nil then
        -- Auto-detect: if all are active, make inactive; otherwise make all active
        local allActive = true
        for _, entity in ipairs(entities) do
            if not entity.active then
                allActive = false
                break
            end
        end
        newState = not allActive
    end
    
    -- Apply new state to all entities
    for _, entity in ipairs(entities) do
        entity.active = newState
    end
    
    -- Award points based on number of entities affected
    if not isProcessingEvents then
        eventBus:push("score_add", {points = #entities * 2})
    else
        score = score + (#entities * 2)
    end
end

-- Event Handler: Spawn a new drifter entity
function EventBus:handleSpawnDrifter(data)
    local x = data.x or love.math.random(50, SCREEN_WIDTH - 50)
    local y = data.y or love.math.random(50, SCREEN_HEIGHT - 50)
    local speed = data.speed or love.math.random(30, 120)
    
    -- Create new entity with drifter behavior and add to entities list
    local entity = Entity:new(x, y, DrifterBehavior:new(speed))
    table.insert(entities, entity)
    
    -- Award points for spawning
    if not isProcessingEvents then
        eventBus:push("score_add", {points = 25})
    else
        score = score + 25
    end
end

-- Event Handler: Add points to the score
function EventBus:handleScoreAdd(data)
    local points = data.points or 0
    score = score + points
end

-- Utility function: Get current number of events waiting in queue
function EventBus:getQueueSize()
    return #self.queue
end

-- Input Handler - Converts keyboard input into events
-- This demonstrates the event-driven pattern: input doesn't directly change game state,
-- instead it posts events that will be processed later during the update loop
local InputHandler = {}

function InputHandler.handleKeyPress(key)
    if key == "space" then
        -- Post event to toggle one random entity
        eventBus:push("toggle_one", {})
    elseif key == "r" then
        -- Post event to toggle all entities
        eventBus:push("toggle_all", {})
    elseif key == "d" then
        -- Post event to spawn a new drifter
        eventBus:push("spawn_drifter", {})
    elseif key == "c" then
        -- Clear all drifters - this is an example of direct manipulation during input
        -- We could also make this an event, but sometimes immediate action is needed
        for i = #entities, 1, -1 do  -- Loop backwards to safely remove items
            local entity = entities[i]
            -- Check if this entity is a drifter by looking for drifter-specific properties
            if entity.behavior and entity.behavior.speed and entity.behavior.vx then 
                table.remove(entities, i)
            end
        end
        -- Post event to subtract points for clearing drifters
        eventBus:push("score_add", {points = -50})
    elseif key == "escape" then
        -- Quit the game immediately
        love.event.quit()
    end
end

-- Helper Functions
-- Count how many entities are currently active (for UI display)
function getActiveCount()
    local count = 0
    for _, entity in ipairs(entities) do
        if entity.active then
            count = count + 1
        end
    end
    return count
end

-- LÖVE2D Callbacks - These are special functions that the LÖVE engine calls automatically
-- LÖVE2D is event-driven itself: it calls these functions at specific times during the game loop

-- Called once when the game starts up
function love.load()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)  -- Set dark gray background
    currentTime = love.timer.getTime()  -- Initialize timing system
    
    -- Initialize event bus - this is our central event management system
    eventBus = EventBus:new()
    
    -- Create initial entities with random behaviors
    for i = 1, 25 do
        local x = love.math.random(50, SCREEN_WIDTH - 50)
        local y = love.math.random(50, SCREEN_HEIGHT - 50)
        local entity
        
        -- Cycle through different behavior types
        local behaviorType = i % 3
        if behaviorType == 0 then
            -- Create a patroller (moves back and forth)
            local speed = love.math.random(50, 150)
            local minX = love.math.random(0, 200)
            local maxX = love.math.random(600, SCREEN_WIDTH)
            entity = Entity:new(x, y, PatrollerBehavior:new(speed, minX, maxX))
        elseif behaviorType == 1 then
            -- Create a drifter (wanders randomly)
            local speed = love.math.random(30, 120)
            entity = Entity:new(x, y, DrifterBehavior:new(speed))
        else
            -- Create an orbiter (moves in circles)
            local centerX = love.math.random(150, SCREEN_WIDTH - 150)
            local centerY = love.math.random(150, SCREEN_HEIGHT - 150)
            local radius = love.math.random(50, 100)
            local speed = love.math.random(1, 3)
            entity = Entity:new(x, y, OrbiterBehavior:new(centerX, centerY, radius, speed))
        end
        
        table.insert(entities, entity)
    end
end

-- Called every frame to update game logic
-- This implements a fixed timestep with accumulator pattern for consistent physics
function love.update(dt)
    -- Fixed timestep with accumulator pattern explanation:
    -- - Game logic always runs at exactly FIXED_TIMESTEP intervals (120 FPS)
    -- - Rendering can happen at different frame rates (60 FPS, 144 FPS, etc.)
    -- - This ensures consistent behavior regardless of monitor refresh rate
    
    local newTime = love.timer.getTime()
    local frameTime = newTime - currentTime  -- How much real time passed this frame
    currentTime = newTime
    
    frameTime = math.min(frameTime, 0.25) -- Prevent spiral of death (if game hangs for >0.25s)
    accumulator = accumulator + frameTime  -- Add frame time to accumulator
    
    local iterations = 0
    -- Run fixed timestep updates until we've caught up to real time
    while accumulator >= FIXED_TIMESTEP and iterations < MAX_ITERATIONS do
        -- Process events first - this is the key part of our event-driven system
        -- Events are processed at the start of each fixed timestep update
        eventBus:processEvents()
        
        -- Update all entities with fixed timestep for consistent movement
        for _, entity in ipairs(entities) do
            entity:update(FIXED_TIMESTEP)
        end
        
        accumulator = accumulator - FIXED_TIMESTEP  -- Subtract the time we just simulated
        iterations = iterations + 1  -- Prevent infinite loops if performance is very bad
    end
end

-- Called every frame to draw everything on screen
-- This runs at the monitor's refresh rate (usually 60 FPS, but could be higher)
function love.draw()
    -- Calculate interpolation alpha for smooth rendering between fixed updates
    -- Alpha represents how far we are between the last update and the next update
    local alpha = accumulator / FIXED_TIMESTEP
    
    -- Render all entities with smooth interpolation
    -- Each entity interpolates between its previous and current position
    for _, entity in ipairs(entities) do
        entity:render(alpha)
    end
    
    -- Draw UI text - set color to white first
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Score: " .. score, 10, 10)
    love.graphics.print("Active entities: " .. getActiveCount() .. "/" .. #entities, 10, 30)
    love.graphics.print("Event queue: " .. eventBus:getQueueSize() .. " events", 10, 50)
    love.graphics.print("", 10, 70)  -- Empty line for spacing
    love.graphics.print("Controls (all via events):", 10, 90)
    love.graphics.print("SPACE - Toggle random entity", 10, 110)
    love.graphics.print("R - Toggle all entities", 10, 130)
    love.graphics.print("D - Spawn drifter", 10, 150)
    love.graphics.print("C - Clear all drifters", 10, 170)
    love.graphics.print("ESC - Quit", 10, 190)
end

-- Called when a key is pressed
-- This is where input enters our event-driven system
function love.keypressed(key)
    -- Input → post pattern: input doesn't directly modify game state,
    -- instead it posts events that will be processed during the next update
    InputHandler.handleKeyPress(key)
end

