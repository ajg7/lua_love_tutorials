local love = require "love"

local Button = require "ui.components.Button"

function Menu(actions)
  actions = actions or {}

  local button_w = 220
  local button_h = 48
  local gap = 14

  local center_x = love.graphics.getWidth() / 2
  local center_y = love.graphics.getHeight() / 2

  local start_x = center_x - button_w / 2
  local start_y = center_y - button_h - gap / 2

  local startButton = Button(start_x, start_y, button_w, button_h, "Start Game", actions.onStart)
  local exitButton = Button(start_x, start_y + button_h + gap, button_w, button_h, "Exit Game", actions.onExit)

  return {
    buttons = { startButton, exitButton },

    update = function(self, mx, my)
      for _, button in ipairs(self.buttons) do
        button:update(mx, my)
      end
    end,

    mousepressed = function(self, mx, my, button)
      for _, btn in ipairs(self.buttons) do
        btn:mousepressed(mx, my, button)
      end
    end,

    draw = function(self)
      love.graphics.setColor(1, 1, 1, 1)

      local title = "ASTEROIDS"
      local font = love.graphics.getFont()
      local title_w = font:getWidth(title)
      love.graphics.print(title, center_x - title_w / 2, center_y - 110)

      for _, btn in ipairs(self.buttons) do
        btn:draw()
      end
    end
  }
end

return Menu
