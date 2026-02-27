local love = require "love"

function Scoreboard(pointsManager)
  return {
    points = pointsManager,

    draw = function(self)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print("SCORE: " .. tostring(self.points:get()), 16, 16)
    end
  }
end

return Scoreboard
