-- Smooth Box Patrol Tutorial
-- Implements fixed timestep with interpolation for smooth movement

-- -- Game state variables
local box = {
  x = 100,
  y = 300,
  prevX = 100,
  prevY = 300,
  speed = 200,
  direction = 1,
  size = 50
}

local FIXED_TIMESTEP = 1/120  -- 120 FPS fixed update (≤ 1/120 s as required)
local MAX_FRAME_TIME = 1/30   -- Safety cap: never simulate more than 1/30 second at once
local accumulator = 0

local windowWidth = 0
local windowHeight = 0

local nudgeAmount = 100  -- pixels per second when arrow key is held

function love.load()
  windowWidth = love.graphics.getWidth()
  windowHeight = love.graphics.getHeight()
  love.window.setTitle("Smooth Box Patrol - Fixed Timestep Demo")
  box.y = windowHeight / 2
  box.prevY = box.y
end

function love.update(dt)
  if dt > MAX_FRAME_TIME then
      dt = MAX_FRAME_TIME
  end

  accumulator = accumulator + dt

  while accumulator >= FIXED_TIMESTEP do
      box.prevX = box.x
      box.prevY = box.y

      -- FIXED TIMESTEP UPDATE - Game logic runs at consistent rate
      fixedUpdate(FIXED_TIMESTEP)

      accumulator = accumulator - FIXED_TIMESTEP
  end
end

function fixedUpdate(dt)
  box.x = box.x + (box.speed * box.direction * dt)

  if love.keyboard.isDown("left") then
      box.x = box.x - nudgeAmount * dt
  end

  if love.keyboard.isDown("right") then
      box.x = box.x + nudgeAmount * dt
  end

  if love.keyboard.isDown("up") then
      box.y = box.y - nudgeAmount * dt
  end

  if love.keyboard.isDown("down") then
      box.y = box.y + nudgeAmount * dt
  end

  if box.x <= box.size / 2 then
    box.x = box.size / 2
    box.direction = 1
  end

  if box.x >= windowWidth - box.size/2 then
    box.x = windowWidth - box.size/2
    box.direction = -1
  end

    if box.y < box.size/2 then
        box.y = box.size/2
    end

    if box.y > windowHeight - box.size/2 then
        box.y = windowHeight - box.size/2
    end
end

function love.draw()
  local alpha = accumulator / FIXED_TIMESTEP

  local renderX = box.prevX + (box.x - box.prevX) * alpha
  local renderY = box.prevY + (box.y - box.prevY) * alpha

  love.graphics.clear(0.1, 0.1, 0.2)

  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", 
      renderX - box.size/2, 
      renderY - box.size/2, 
      box.size, 
      box.size)

  love.graphics.setColor(1, 1, 1)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
