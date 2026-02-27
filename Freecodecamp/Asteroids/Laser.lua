local love = require "love"

function Laser(x, y, angle)
  local speed = 700
  local lifetime = 0.9

  return {
    x = x,
    y = y,
    angle = angle,
    dx = speed * math.cos(angle),
    dy = speed * math.sin(angle),
    life = lifetime,

    update = function(self, dt)
      self.x = self.x + self.dx * dt
      self.y = self.y + self.dy * dt
      self.life = self.life - dt
    end,

    isDead = function(self)
      return self.life <= 0
    end,

    draw = function(self)
      local len = 18
      local hx = (len / 2) * math.cos(self.angle)
      local hy = (len / 2) * math.sin(self.angle)

      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.line(self.x - hx, self.y - hy, self.x + hx, self.y + hy)
    end
  }
end

return Laser
