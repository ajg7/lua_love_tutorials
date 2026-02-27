function PointsManager()
  return {
    score = 0,

    reset = function(self)
      self.score = 0
    end,

    add = function(self, points)
      self.score = self.score + (points or 0)
    end,

    get = function(self)
      return self.score
    end,

    awardForAsteroid = function(self, asteroidSize)
      -- Classic Asteroids scoring: large=20, medium=50, small=100
      if asteroidSize == 3 then
        self:add(20)
      elseif asteroidSize == 2 then
        self:add(50)
      elseif asteroidSize == 1 then
        self:add(100)
      end
    end
  }
end

return PointsManager
