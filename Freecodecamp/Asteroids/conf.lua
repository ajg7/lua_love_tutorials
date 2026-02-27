local love = require "love"

function love.conf(app)
  app.window.width = 1280
  app.window.height = 720
  app.window.title = "Asteroids"
  app.window.display = 2
end