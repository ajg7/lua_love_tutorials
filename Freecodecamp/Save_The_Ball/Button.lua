local love = require "love"

local function Button(text, func, func_param, width, height)
  local button = {
    width = width or 100,
    height = height or 40,
    func = func or function() print("This button doesnt have a function") end,
    func_param = func_param,
    text = text or "Button",
    button_x = 0,
    button_y = 0,
    text_x = 0,
    text_y = 0,
  }

  function button:draw(button_x, button_y, text_x, text_y)
    self.button_x = button_x or self.button_x
    self.button_y = button_y or self.button_y
    self.text_x = text_x or self.text_x
    self.text_y = text_y or self.text_y

    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle("fill", self.button_x, self.button_y, self.width, self.height)

    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(self.text, love.graphics.newFont(16), self.text_x, self.text_y, self.width, "center")

    love.graphics.setColor(1, 1, 1)
  end

  function button:checkPressed(mouse_x, mouse_y, mouse_button, istouch, presses)
    if mouse_button ~= 1 then
      return
    end

    local within_x = mouse_x >= self.button_x and mouse_x <= (self.button_x + self.width)
    local within_y = mouse_y >= self.button_y and mouse_y <= (self.button_y + self.height)
    if within_x and within_y then
      if self.func_param ~= nil then
        self.func(self.func_param)
      else
        self.func()
      end
    end
  end

  return button
end

return Button