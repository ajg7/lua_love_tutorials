local love = require "love"

function GameOver(pointsManager, maxHits)
  return {
    points = pointsManager,
    maxHits = maxHits or 3,

    draw = function(self)
      local w = love.graphics.getWidth()
      local h = love.graphics.getHeight()

      love.graphics.setColor(1, 1, 1, 1)

      local title = "GAME OVER"
      local font = love.graphics.getFont()
      local title_w = font:getWidth(title)
      love.graphics.print(title, (w - title_w) / 2, h / 2 - 40)

      local scoreText = "FINAL SCORE: " .. tostring(self.points and self.points:get() or 0)
      local score_w = font:getWidth(scoreText)
      love.graphics.print(scoreText, (w - score_w) / 2, h / 2)
    end
  }
end

return GameOver
