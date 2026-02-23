-- Micro-Engine for LÖVE with Fixed Timestep
-- Requirements: 25 squares, different behaviors, clean game loop, fixed timestep


local FIXED_TIMESTEP = 1/120 -- ≤ 1/120s as required
local MAX_ITERATIONS = 5     -- Guard against spiral of death
local SCREEN_WIDTH = 800
local SCREEN_HEIGHT = 600
local SQUARE_SIZE = 20

local entities = {}
local accumulator = 0
local currentTime = 0 

local Entity = {}
Entity.__index = Entity

function Entity:new(x, y, behavior)
  local entity = {
      x = x or 0,
      y = y or 0,
      prevX = x or 0,
      prevY = y or 0,
      active = true,
      behavior = behavior,
      color = {love.math.random(), love.math.random(), love.math.random()}
  }

  setmetatable(entity, self)
  return entity
end

function Entity:update(dt)
  if not self.active then return end
  self.prevX = self.x
  self.prevY = self.y

  if self.behavior and self.behavior.update then
      self.behavior:update(self, dt)
  end
end

function Entity:render(alpha)
  if not self.active then return end
  
  local renderX = self.prevX + (self.x - self.prevX) * alpha
  local renderY = self.prevY + (self.y - self.prevY) * alpha

  love.graphics.setColor(self.color)
  love.graphics.rectangle("fill", renderX, renderY, SQUARE_SIZE, SQUARE_SIZE)
end

function Entity:toggleActive()
    self.active = not self.active
end

local PatrollerBehavior = {}
PatrollerBehavior.__index = PatrollerBehavior

function PatrollerBehavior:new(speed, minX, maxX)
    local behavior = {
        speed = speed or 100,
        minX = minX or 50,
        maxX = maxX or SCREEN_WIDTH - 50,
        direction = 1
    }
    setmetatable(behavior, self)
    return behavior
end

function PatrollerBehavior:update(entity, dt)
    entity.x = entity.x + self.speed * self.direction * dt
    
    -- Bounce at boundaries
    if entity.x <= self.minX or entity.x >= self.maxX then
        self.direction = -self.direction
        entity.x = math.max(self.minX, math.min(self.maxX, entity.x))
    end
end

local DrifterBehavior = {}
DrifterBehavior.__index = DrifterBehavior

function DrifterBehavior:new(speed)
  local behavior = {
    speed = speed or 80,
    vx = love.math.random(-1, 1),
    vy = love.math.random(-1, 1),
    changeTimer = 0,
    changeInterval = love.math.random(1, 3)
  }
  setmetatable(behavior, self)
  return behavior
end

function DrifterBehavior:update(entity, dt)
  entity.x = entity.x + self.vx * self.speed * dt
  entity.y = entity.y + self.vy * self.speed * dt

  if entity.x < 0 then entity.x = SCREEN_WIDTH end
  if entity.x > SCREEN_WIDTH then entity.x = 0 end
  if entity.y < 0 then entity.y = SCREEN_HEIGHT end
  if entity.y > SCREEN_HEIGHT then entity.y = 0 end
  
  self.changeTimer = self.changeTimer + dt
  if self.changeTimer >= self.changeInterval then
      self.vx = love.math.random(-1, 1)
      self.vy = love.math.random(-1, 1)
      self.changeTimer = 0
      self.changeInterval = love.math.random(1, 3)
  end
end

local OrbiterBehavior = {}
OrbiterBehavior.__index = OrbiterBehavior

function OrbiterBehavior:new(centerX, centerY, radius, speed)
    local behavior = {
        centerX = centerX or SCREEN_WIDTH/2,
        centerY = centerY or SCREEN_HEIGHT/2,
        radius = radius or 100,
        speed = speed or 2,
        angle = love.math.random() * math.pi * 2
    }
    setmetatable(behavior, self)
    return behavior
end

function OrbiterBehavior:update(entity, dt)
    self.angle = self.angle + self.speed * dt
    entity.x = self.centerX + math.cos(self.angle) * self.radius
    entity.y = self.centerY + math.sin(self.angle) * self.radius
end

function love.load()
  love.graphics.setBackgroundColor(0.1, 0.1, 0.1)
  currentTime = love.timer.getTime()
  for i = 1, 25 do
    local x = love.math.random(50, SCREEN_WIDTH - 50)
    local y = love.math.random(50, SCREEN_HEIGHT - 50)
    local entity

    local behaviorType = i % 3
    if behaviorType == 0 then
        local speed = love.math.random(50, 150)
        local minX = love.math.random(0, 200)
        local maxX = love.math.random(600, SCREEN_WIDTH)
        entity = Entity:new(x, y, PatrollerBehavior:new(speed, minX, maxX))
    elseif behaviorType == 1 then
        local speed = love.math.random(30, 120)
        entity = Entity:new(x, y, DrifterBehavior:new(speed))
    else
        local centerX = love.math.random(150, SCREEN_WIDTH - 150)
        local centerY = love.math.random(150, SCREEN_HEIGHT - 150)
        local radius = love.math.random(50, 100)
        local speed = love.math.random(1, 3)
        entity = Entity:new(x, y, OrbiterBehavior:new(centerX, centerY, radius, speed))
    end

    table.insert(entities, entity)
  end
end

function love.update(dt)
    -- Fixed timestep with accumulator pattern
    local newTime = love.timer.getTime()
    local frameTime = newTime - currentTime
    currentTime = newTime
    
    -- Clamp frame time to prevent spiral of death
    frameTime = math.min(frameTime, 0.25)
    
    accumulator = accumulator + frameTime
    
    local iterations = 0
    while accumulator >= FIXED_TIMESTEP and iterations < MAX_ITERATIONS do
        -- Update all entities with fixed timestep
        for _, entity in ipairs(entities) do
            entity:update(FIXED_TIMESTEP)
        end
        
        accumulator = accumulator - FIXED_TIMESTEP
        iterations = iterations + 1
    end
end

function love.draw()
  local alpha = accumulator / FIXED_TIMESTEP

  for _, entity in ipairs(entities) do
      entity:render(alpha)
  end

  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Active entities: " .. getActiveCount(), 10, 10)
  love.graphics.print("Press SPACE to toggle random entity", 10, 30)
  love.graphics.print("Press R to toggle all entities", 10, 50)
  love.graphics.print("Fixed timestep: " .. FIXED_TIMESTEP .. "s", 10, 70)
end

function love.keypressed(key)
    if key == "space" then
        -- Toggle a random entity to demonstrate active/inactive functionality
        local randomEntity = entities[love.math.random(1, #entities)]
        randomEntity:toggleActive()
    elseif key == "r" then
        -- Toggle all entities
        local allActive = true
        for _, entity in ipairs(entities) do
            if not entity.active then
                allActive = false
                break
            end
        end
        
        for _, entity in ipairs(entities) do
            entity.active = not allActive
        end
    elseif key == "escape" then
        love.event.quit()
    end
end

-- Helper function to count active entities
function getActiveCount()
    local count = 0
    for _, entity in ipairs(entities) do
        if entity.active then
            count = count + 1
        end
    end
    return count
end