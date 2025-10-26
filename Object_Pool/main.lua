local FIXED_DT, MAX_ITERS = 1/120, 8
local acc = 0
local W, H = 800, 600
local POOL_SIZE = 200

local Particle = {}
Particle.__index = Particle
function Particle:new()
  return setmetatable({
    x = 0,
    y = 0,
    px = 0,
    py = 0,
    vx = 0,
    vy = 0,
    life = 0
  }, self)
end

function Particle:init(x, y, vx, vy, life) 
  self.x, self.y = x, y
  self.vx, self.vy = vx, vy
  self.px, self.py = x, y
  self.life = life
end

function Particle:update(dt)
  if self.life <= 0 then return end
  self.px, self.py = self.x, self.y
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
  self.life = self.life - dt
end

function Particle:draw(alpha)
  if self.life <= 0 then return end
  local rx = self.px + (self.x - self.px) * alpha
  local ry = self.py + (self.y - self.py) * alpha
  love.graphics.rectangle("fill", rx, ry, 3, 3)
end

function Particle:inUse() return self.life > 0 end

local Pool = { items = {}, size = POOL_SIZE }
function Pool:init() 
  for i = 1, self.size do
    self.items[i] = Particle:new()
  end
end

function Pool:create(x, y, vx, vy, life) 
  for i = 1, self.size do
    local p = self.items[i]
    if not p:inUse() then
      p:init(x, y, vx, vy, life)
      return p
    end
  end
  return nil
end

function Pool:update(dt)
  for i = 1,self.size do self.items[i]:update(dt) end
end
function Pool:draw(alpha)
  for i = 1,self.size do self.items[i]:draw(alpha) end
end

local pool = Pool
local emitter = { x = W/2, y = H/2, burst = 60 }

function love.load()
  love.window.setMode(W, H)
  love.graphics.setBackgroundColor(0.08,0.09,0.12)
  pool:init()
end

local function emitBurst(n)
  for i = 1, n do
    local angle = love.math.random() * 2 * math.pi
    local speed = love.math.random(80, 220)
    local vx = math.cos(angle) * speed
    local vy = math.sin(angle) * speed
    pool:create(emitter.x, emitter.y, vx, vy, 2)
  end
end

local function fixedUpdate()
  pool:update(FIXED_DT)
end

function love.update(dt)
  dt = math.min(dt, 0.10)            -- clamp spike
  acc = acc + dt
  local it = 0
  while acc >= FIXED_DT and it < MAX_ITERS do
    fixedUpdate()
    acc, it = acc - FIXED_DT, it + 1
  end
  if it == MAX_ITERS then acc = 0 end -- panic dump
end

function love.draw()
  local a = acc / FIXED_DT; if a > 1 then a = 1 end
  love.graphics.setColor(1,1,1)
  pool:draw(a)
  love.graphics.print("Press SPACE to emit, drag mouse to move emitter", 10, 10)
  love.graphics.print("Active (approx): "..countActive(pool), 10, 30)
end

function countActive(p)
  local n = 0; for i = 1,p.size do if p.items[i]:inUse() then n = n + 1 end end; return n
end

function love.keypressed(k)
  if k == "space" then emitBurst(emitter.burst) end
  if k == "escape" then love.event.quit() end
end

function love.mousemoved(x,y) emitter.x, emitter.y = x,y end
