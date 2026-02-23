-- main.lua — Dirty Flag + cached UI (Beginner)
local FIXED_DT, MAX_ITERS = 1/120, 8
local acc = 0

local game = { score = 0, level = 1 }

local HUD = {
  dirty = true,
  canvas = nil,
  w = 260, h = 80
}

function HUD:init() 
  self.canvas = love.graphics.newCanvas(self.w, self.h)
  self.dirty = true
end

function HUD:rebuildIfDirty()
  if not self.dirty then return end
  love.graphics.push("all")
  love.graphics.setCanvas(self.canvas)
  love.graphics.clear()

  love.graphics.setColor(0.15, 0.2, 0.28)
  love.graphics.rectangle("fill", 0, 0, self.w, self.h, 8, 8)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(("Score: %d"):format(game.score), 12, 12)
  love.graphics.print(("Level: %d"):format(game.level), 12, 36)

  love.graphics.setCanvas()
  love.graphics.pop()
  self.dirty = false
end

function HUD:draw()
  self:rebuildIfDirty()
  love.graphics.setColor(1,1,1)
  love.graphics.draw(self.canvas, 10, 10)
end

local function fixedUpdate()
  -- pretend “game” updates rarely make the HUD change
end

function love.load()
  love.window.setTitle("Dirty Flag Demo — Cached HUD")
  love.graphics.setBackgroundColor(0.08, 0.09, 0.12)
  HUD:init()
end

function love.update(dt)
  dt = math.min(dt, 0.10)
  acc = acc + dt
  local it = 0
  while acc >= (1/120) and it < 8 do
    fixedUpdate()
    acc, it = acc - (1/120), it + 1
  end
  if it == 8 then acc = 0 end
end

function love.draw()
  -- world (placeholder)
  love.graphics.setColor(1,1,1)
  love.graphics.print("Press [UP]/[DOWN] to change Level, [SPACE] to +10 Score", 16, 16)

  -- draw cached HUD (rebuilds only when dirty)
  HUD:draw(16, 48)
end

function love.keypressed(k)
  if k == "space" then
    game.score = game.score + 10
    HUD.dirty = true      -- mark cache invalid
  elseif k == "up" then
    game.level = game.level + 1
    HUD.dirty = true
  elseif k == "down" then
    game.level = math.max(1, game.level - 1)
    HUD.dirty = true
  elseif k == "escape" then
    love.event.quit()
  end
end
