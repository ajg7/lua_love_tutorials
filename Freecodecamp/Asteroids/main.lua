local love = require "love"

local Player = require "Player"
local Laser = require "Laser"
local Asteroid = require "Asteroid"
local PointsManager = require "managers.PointsManager"
local Game = require "states.Game"
local Menu = require "states.Menu"
local GameOver = require "states.GameOver"
local Scoreboard = require "ui.components.Scoreboard"

local function dist2(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return dx * dx + dy * dy
end

local function spawnAsteroidAwayFrom(x, y, minDist, size)
  local tries = 0
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()
  local minD2 = minDist * minDist

  while tries < 40 do
    tries = tries + 1

    -- Spawn from an edge (classic Asteroids vibe)
    local edge = love.math.random(1, 4)
    local ax, ay
    if edge == 1 then
      ax, ay = -20, love.math.random(0, h)
    elseif edge == 2 then
      ax, ay = w + 20, love.math.random(0, h)
    elseif edge == 3 then
      ax, ay = love.math.random(0, w), -20
    else
      ax, ay = love.math.random(0, w), h + 20
    end

    if dist2(x, y, ax, ay) >= minD2 then
      return Asteroid(size, ax, ay)
    end
  end

  return Asteroid(size)
end

function love.load()
  mouse_x, mouse_y = 0, 0

  show_debugging = false

  game = Game()
  game:changeGameState("menu")

  love.mouse.setVisible(true)

  local function startGame()
    player = Player(show_debugging)

    points = PointsManager()
    scoreboard = Scoreboard(points)

    hits = 0
    maxHits = 3
    gameOver = GameOver(points, maxHits)

    lasers = {}
    laserCooldown = 0

    asteroids = {}
    for i = 1, 4 do
      asteroids[#asteroids + 1] = spawnAsteroidAwayFrom(player.x, player.y, 160, 3)
    end

    game:changeGameState("running")
    love.mouse.setVisible(false)
  end

  menu = Menu({
    onStart = startGame,
    onExit = function()
      love.event.quit()
    end
  })
end

function love.keypressed(key)
  if game.state.running then
    if key == "w" or key == "up" or key == "kp8" then
      player.thrusting = true
    elseif key == "space" then
      fireLaser()
    end
  end
end

function love.keyreleased(key) 
  if game.state.running then
    if key == "w" or key == "up" or key == "kp8" then
      player.thrusting = false
    end
  end
end

function love.mousepressed(x, y, button)
  if game.state.menu then
    menu:mousepressed(x, y, button)
  elseif game.state.running then
    if button == 1 then
      fireLaser()
    end
  end
end

function fireLaser()
  if not game or not game.state.running then
    return
  end

  if laserCooldown and laserCooldown > 0 then
    return
  end

  local nose_x = player.x + ((4 / 3) * player.radius) * math.cos(player.angle)
  local nose_y = player.y + ((4 / 3) * player.radius) * math.sin(player.angle)

  lasers[#lasers + 1] = Laser(nose_x, nose_y, player.angle)
  laserCooldown = 0.18
end

function love.update(dt)
  mouse_x, mouse_y = love.mouse.getPosition()

  if game.state.menu then
    menu:update(mouse_x, mouse_y)
  end

  if game.state.running then
    if laserCooldown and laserCooldown > 0 then
      laserCooldown = laserCooldown - dt
      if laserCooldown < 0 then
        laserCooldown = 0
      end
    end

    player:movePlayer()

    for i = #lasers, 1, -1 do
      local laser = lasers[i]
      laser:update(dt)
      if laser:isDead() then
        table.remove(lasers, i)
      end
    end

    for i = #asteroids, 1, -1 do
      local asteroid = asteroids[i]
      asteroid:update(dt)

      local hitDist = player.radius + asteroid.radius
      if dist2(player.x, player.y, asteroid.x, asteroid.y) <= hitDist * hitDist then
        hits = hits + 1

        if hits >= maxHits then
          game:changeGameState("ended")
          love.mouse.setVisible(true)
          player.thrusting = false
          player.thrust.x = 0
          player.thrust.y = 0
          break
        end

        -- Simple reset so we don't immediately collide again.
        player.x = love.graphics.getWidth() / 2
        player.y = love.graphics.getHeight() / 2
        player.thrusting = false
        player.thrust.x = 0
        player.thrust.y = 0

        break
      end
    end

    if game.state.running then
      for li = #lasers, 1, -1 do
        local laser = lasers[li]
        for ai = #asteroids, 1, -1 do
          local asteroid = asteroids[ai]

          if dist2(laser.x, laser.y, asteroid.x, asteroid.y) <= asteroid.radius * asteroid.radius then
            points:awardForAsteroid(asteroid.size)
            local children = asteroid:split()
            table.remove(asteroids, ai)
            for _, child in ipairs(children) do
              asteroids[#asteroids + 1] = child
            end

            table.remove(lasers, li)
            break
          end
        end
      end
    end

    if #asteroids == 0 then
      for i = 1, 4 do
        asteroids[#asteroids + 1] = spawnAsteroidAwayFrom(player.x, player.y, 160, 3)
      end
    end
  end
end

function love.draw()
  if game.state.menu then
    menu:draw()
  elseif game.state.running then
    for _, laser in ipairs(lasers) do
      laser:draw()
    end
    for _, asteroid in ipairs(asteroids) do
      asteroid:draw(show_debugging)
    end
    player:draw()
    scoreboard:draw()
  elseif game.state.ended then
    gameOver:draw()
  end
end