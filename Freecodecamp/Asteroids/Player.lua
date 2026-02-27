---@diagnostic disable: lowercase-global

local love = require "love"

function Player(debugging)
  local SHIP_SIZE = 30
  local VIEW_ANGLE = math.rad(90)
  local THRUST_SPEED = 5
  
  debugging = debugging or false

  return {
    x = love.graphics.getWidth() / 2,
    y = love.graphics.getHeight() / 2,
    radius = SHIP_SIZE / 2,
    angle = VIEW_ANGLE,
    rotation = 0,
    thrusting = false,
    thrust = {
      x = 0,
      y = 0,
      speed = THRUST_SPEED
    },

    draw = function (self)
      local opacity = 1
      if debugging then
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", self.x, self.y, 2, 2)
        love.graphics.circle("line", self.x, self.y, self.radius, 10)
      end

      if self.thrusting then
        local rear_mid_x = self.x - self.radius * (2 / 3) * math.cos(self.angle)
        local rear_mid_y = self.y - self.radius * (2 / 3) * math.sin(self.angle)

        local flame_length = self.radius * (1.0 + 0.25 * math.sin(love.timer.getTime() * 30))
        local flame_width = self.radius * 0.6

        local flame_tip_x = rear_mid_x - flame_length * math.cos(self.angle)
        local flame_tip_y = rear_mid_y - flame_length * math.sin(self.angle)

        local flame_left_x = rear_mid_x + flame_width * math.cos(self.angle + math.pi / 2)
        local flame_left_y = rear_mid_y + flame_width * math.sin(self.angle + math.pi / 2)
        local flame_right_x = rear_mid_x + flame_width * math.cos(self.angle - math.pi / 2)
        local flame_right_y = rear_mid_y + flame_width * math.sin(self.angle - math.pi / 2)

        love.graphics.setColor(1, 0.15, 0.05, opacity)
        love.graphics.polygon(
          "line",
          flame_left_x, flame_left_y,
          flame_tip_x, flame_tip_y,
          flame_right_x, flame_right_y
        )
      end

      love.graphics.setColor(1, 1, 1, opacity)
      love.graphics.polygon(
        "line",
        self.x + ((4 / 3) * self.radius) * math.cos(self.angle),
        self.y + ((4 / 3) * self.radius) * math.sin(self.angle),
        self.x - self.radius * ((2 / 3) * math.cos(self.angle) + math.sin(self.angle)),
        self.y - self.radius * ((2 / 3) * math.sin(self.angle) - math.cos(self.angle)),
        self.x - self.radius * ((2 / 3) * math.cos(self.angle) - math.sin(self.angle)),
        self.y - self.radius * ((2 / 3) * math.sin(self.angle) + math.cos(self.angle))
      )
    end,

    movePlayer = function (self)
      local FPS = love.timer.getFPS()
      local friction = 0.7

      self.rotation = 360 / 180 * math.pi / FPS

      if love.keyboard.isDown("right") then
        self.angle = self.angle + self.rotation
      elseif love.keyboard.isDown("left") then
        self.angle = self.angle - self.rotation
      end

      if self.thrusting then
        self.thrust.x = self.thrust.x + self.thrust.speed * math.cos(self.angle) / FPS
        self.thrust.y = self.thrust.y + self.thrust.speed * math.sin(self.angle) / FPS
      else
        if self.thrust.x ~= 0 or self.thrust.y ~= 0 then
          self.thrust.x = self.thrust.x - friction * self.thrust.x / FPS
          self.thrust.y = self.thrust.y - friction * self.thrust.y / FPS
        end
      end

      self.x = self.x + self.thrust.x
      self.y = self.y + self.thrust.y

      local w = love.graphics.getWidth()
      local h = love.graphics.getHeight()
      -- Keep the entire ship (and thrust flame) on-screen.
      local margin = self.radius * 2
      if self.x < margin then
        self.x = margin
      elseif self.x > (w - margin) then
        self.x = (w - margin)
      end

      if self.y < margin then
        self.y = margin
      elseif self.y > (h - margin) then
        self.y = (h - margin)
      end
    end
  }
end

return Player