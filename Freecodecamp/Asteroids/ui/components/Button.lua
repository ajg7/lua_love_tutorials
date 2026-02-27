local love = require "love"

local function pointInRect(px, py, x, y, w, h)
  return px >= x and px <= x + w and py >= y and py <= y + h
end

function Button(x, y, w, h, text, onClick)
  return {
    x = x,
    y = y,
    w = w,
    h = h,
    text = text or "",
    onClick = onClick,
    hovered = false,

    update = function(self, mx, my)
      self.hovered = pointInRect(mx, my, self.x, self.y, self.w, self.h)
    end,

    mousepressed = function(self, mx, my, button)
      if button ~= 1 then
        return
      end

      if self.hovered and type(self.onClick) == "function" then
        self.onClick()
      end
    end,

    draw = function(self)
      if self.hovered then
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
      end

      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("line", self.x, self.y, self.w, self.h)

      local font = love.graphics.getFont()
      local text_w = font:getWidth(self.text)
      local text_h = font:getHeight()
      love.graphics.print(
        self.text,
        self.x + (self.w - text_w) / 2,
        self.y + (self.h - text_h) / 2
      )
    end
  }
end

return Button
