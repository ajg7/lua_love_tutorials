-- main.lua — Optional Patterns Sampler 
--    (Command, Flyweight, Observer, Prototype, Singleton, State)
-- Keys:
--   Arrows = enqueue Move Command   |   Z = Undo   |   Y = Redo
--   SPACE  = Toggle Dash state      |   E = Spawn enemy (Prototype)
--   F1     = Toggle debug (Singleton Config)

---------------------------------------------------------------------
-- Fixed timestep scaffold (keeps motion stable)
---------------------------------------------------------------------
local FIXED_DT, MAX_ITERS = 1/120, 8
local accumulator = 0
local WINDOW_WIDTH, WINDOW_HEIGHT = 800, 600

function love.load()
  love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
  love.graphics.setBackgroundColor(0.08, 0.09, 0.12)
  rng.seed(1)
  HUD:init()
  Starfield:init(180)        -- Flyweight demo: lots of stars share one shape
  player = Player.new(120, 280)
  table.insert(enemies, spawnEnemy(EnemyProto, 520, 240)) -- Prototype demo
end

function love.update(dt)
  dt = math.min(dt, 0.10)
  accumulator = accumulator + dt
  local iterations = 0
  while accumulator >= FIXED_DT and iterations < MAX_ITERS do
    fixedUpdate()
    accumulator = accumulator - FIXED_DT
    iterations = iterations + 1
  end
  if iterations == MAX_ITERS then accumulator = 0 end
end

function love.draw()
  local alpha = math.min(1, accumulator / FIXED_DT)
  Starfield:draw(alpha)                        -- Flyweight
  for _, enemy in ipairs(enemies) do enemy:draw(alpha) end
  player:draw(alpha)

  HUD:draw(10, 10)                         -- Observer-based HUD

  if Config.get().debug then
    love.graphics.setColor(1,1,1,0.9)
    love.graphics.print(("History:%d  Redo:%d  Enemies:%d  Stars:%d")
      :format(#history, #redoStack, #enemies, Starfield.count), 10, WINDOW_HEIGHT - 22)
  end
  love.graphics.setColor(1,1,1,1)
end

---------------------------------------------------------------------
-- RNG (tiny helper)
---------------------------------------------------------------------
rng = { _r = 1 }
function rng.seed(seed) rng._r = seed or 1 end
function rng.float()
  rng._r = (1103515245 * rng._r + 12345) % 2^31
  return (rng._r / 2^31)
end

---------------------------------------------------------------------
-- Singleton (Config) — controversial, used minimally
-- Access through Config.get() so there is one shared table. [PDF: p.73–84]
---------------------------------------------------------------------
Config = (function()
  local instance = { debug = false }
  return {
    get = function() return instance end
  }
end)()

---------------------------------------------------------------------
-- Observer — Score subject + HUD observer [PDF: p.43–57]
---------------------------------------------------------------------
local Subject = {}
Subject.__index = Subject
function Subject.new()
  return setmetatable({ obs = {} }, Subject)
end
function Subject:add(fn) table.insert(self.obs, fn) end
function Subject:notify(ev) for _,fn in ipairs(self.obs) do fn(ev) end end

Score = { value = 0, subject = Subject.new() }
function Score:add(n)
  self.value = self.value + (n or 0)
  self.subject:notify({ type="score", value=self.value })
end

HUD = { text = "", dirty = true, canvas = nil, w=260, h=54 }
function HUD:init()
  self.canvas = love.graphics.newCanvas(self.w, self.h)
  Score.subject:add(function(ev)
    if ev.type == "score" then self.dirty = true end
  end)
  self.dirty = true
end
function HUD:rebuild()
  if not self.dirty then return end
  love.graphics.push("all")
  love.graphics.setCanvas(self.canvas)
  love.graphics.clear(0,0,0,0)
  love.graphics.setColor(0.15,0.2,0.28); love.graphics.rectangle("fill", 0,0, self.w, self.h, 8,8)
  love.graphics.setColor(1,1,1)
  love.graphics.print(("Score: %d"):format(Score.value), 12, 10)
  love.graphics.print("Arrows=Move, Z/Y=Undo/Redo, SPACE=Dash", 12, 30)
  love.graphics.setCanvas()
  love.graphics.pop()
  self.dirty = false
end
function HUD:draw(x,y) self:rebuild(); love.graphics.setColor(1,1,1); love.graphics.draw(self.canvas, x,y) end

---------------------------------------------------------------------
-- Flyweight — one intrinsic star shape shared by many instances [PDF: p.33–41]
-- Intrinsic: STAR_VERTS; Extrinsic: each star's x,y,angle,scale
---------------------------------------------------------------------
local STAR_VERTS = {
  0,-6,   2,-2,   6,-2,   3,1,   4,6,   0,3,   -4,6,  -3,1,  -6,-2, -2,-2
}
Starfield = { stars = {}, count = 0 }
function Starfield:init(count)
  self.stars = {}; self.count = count
  for i = 1, count do
    self.stars[i] = {
      x = rng.float() * WINDOW_WIDTH,
      y = rng.float() * WINDOW_HEIGHT,
      angle = rng.float() * math.pi * 2,
      angularVelocity = (rng.float() * 2 - 1) * 0.6,
      scale = 0.7 + rng.float() * 0.8
    }
  end
end
function Starfield:update(dt)
  for i = 1, self.count do
    local star = self.stars[i]
    star.angle = star.angle + star.angularVelocity * dt
  end
end
function Starfield:draw(alpha)
  self:update(FIXED_DT * math.max(1, alpha)) -- cheap drift
  love.graphics.setColor(1,1,1,0.25)
  for i = 1, self.count do
    local star = self.stars[i]
    love.graphics.push()
    love.graphics.translate(star.x, star.y)
    love.graphics.rotate(star.angle)
    love.graphics.scale(star.scale, star.scale)
    love.graphics.polygon("line", STAR_VERTS) -- shared intrinsic data
    love.graphics.pop()
  end
  love.graphics.setColor(1,1,1,1)
end

---------------------------------------------------------------------
-- Prototype — template enemy table, spawn by deep copy [PDF: p.59–71]
---------------------------------------------------------------------
local function deepcopy(t)
  if type(t)~="table" then return t end
  local result = {}
  for key, value in pairs(t) do result[key] = deepcopy(value) end
  return result
end

EnemyProto = {
  w=24, h=16, color={1,0.6,0.6}, vx=-80, vy=0,
  update = function(self, dt)
    self.px, self.py = self.x, self.y
    self.x = self.x + self.vx * dt
    -- wrap
    if self.x + self.w < 0 then self.x = WINDOW_WIDTH + 40 end
  end,
  draw = function(self, alpha)
    local renderX = self.px + (self.x - self.px) * alpha
    local renderY = self.py + (self.y - self.py) * alpha
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", renderX, renderY, self.w, self.h)
    love.graphics.setColor(1,1,1)
  end
}

enemies = {}
function spawnEnemy(proto, x, y)
  local enemy = deepcopy(proto)
  enemy.x, enemy.y, enemy.px, enemy.py = x, y, x, y
  table.insert(enemies, enemy)
  Score:add(1) -- observer will update HUD
  return enemy
end

---------------------------------------------------------------------
-- State — Player FSM: Idle <-> Dash [PDF: p.87–104]
---------------------------------------------------------------------
Player = {}
Player.__index = Player

local Idle = {
  name="Idle",
  enter = function(self, playerInstance) playerInstance.speedMul = 1 end,
  update = function(self, playerInstance, dt) end
}
local Dash = {
  name="Dash", t=0, dur=0.25, boost=2.8,
  enter = function(self, playerInstance) self.t = 0; playerInstance.speedMul = self.boost end,
  update = function(self, playerInstance, dt)
    self.t = self.t + dt
    if self.t >= self.dur then playerInstance:setState(Idle) end
  end
}

function Player.new(x,y)
  local p = setmetatable({ x=x,y=y, px=x,py=y, w=28,h=28, baseSpeed=140, speedMul=1 }, Player)
  p:setState(Idle)
  return p
end
function Player:setState(s)
  self.state = s
  if s.enter then s:enter(self) end
end
function Player:update(dt)
  self.px, self.py = self.x, self.y
  self.state:update(self, dt)
end
function Player:move(dx,dy) -- used by Commands
  local sp = self.baseSpeed * (self.speedMul or 1)
  self.x = math.max(0, math.min(WINDOW_WIDTH - self.w, self.x + dx * sp * FIXED_DT))
  self.y = math.max(0, math.min(WINDOW_HEIGHT - self.h, self.y + dy * sp * FIXED_DT))
end
function Player:draw(alpha)
  local renderX = self.px + (self.x - self.px) * alpha
  local renderY = self.py + (self.y - self.py) * alpha
  love.graphics.setColor(0.6, 1.0, 0.7)
  love.graphics.rectangle("fill", renderX, renderY, self.w, self.h)
  love.graphics.setColor(1,1,1)
  love.graphics.print(("State: %s  x=%.1f y=%.1f"):format(self.state.name, self.x, self.y), 10, 70)
end

---------------------------------------------------------------------
-- Command — input as command objects with undo/redo [PDF: p.21–28]
---------------------------------------------------------------------
local function newCommand(t)
  t.execute = t.execute or function(self) end
  t.undo    = t.undo    or function(self) end
  return t
end
local function MoveCommand(dx, dy)
  return newCommand({
    dx=dx, dy=dy,
    prev=nil,
    execute = function(self)
      self.prev = {x=player.x, y=player.y}
      player:move(self.dx, self.dy)
    end,
    undo = function(self)
      if not self.prev then return end
      player.x, player.y = self.prev.x, self.prev.y
    end
  })
end

history, redoStack = {}, {}
local function doCommand(cmd)
  cmd:execute()
  table.insert(history, cmd)
  for i=#redoStack,1,-1 do table.remove(redoStack, i) end
end
local function undo()
  local cmd = history[#history]; if not cmd then return end
  cmd:undo(); table.remove(history); table.insert(redoStack, cmd)
end
local function redo()
  local cmd = redoStack[#redoStack]; if not cmd then return end
  table.remove(redoStack); cmd:execute(); table.insert(history, cmd)
end

---------------------------------------------------------------------
-- Per-step update for world
---------------------------------------------------------------------
function fixedUpdate()
  -- update enemies
  for _, enemy in ipairs(enemies) do enemy:update(FIXED_DT) end
  -- update player state
  player:update(FIXED_DT)
end

---------------------------------------------------------------------
-- Input
---------------------------------------------------------------------
function love.keypressed(k)
  if     k=="left"  then doCommand(MoveCommand(-1, 0))
  elseif k=="right" then doCommand(MoveCommand( 1, 0))
  elseif k=="up"    then doCommand(MoveCommand( 0,-1))
  elseif k=="down"  then doCommand(MoveCommand( 0, 1))
  elseif k=="z"     then undo()
  elseif k=="y"     then redo()
  elseif k=="space" then
    if player.state ~= Dash then player:setState(Dash) else player:setState(Idle) end
  elseif k=="e"     then spawnEnemy(EnemyProto, rng.float()*(WINDOW_WIDTH-60)+30, rng.float()*(WINDOW_HEIGHT-60)+30)
  elseif k=="f1"    then Config.get().debug = not Config.get().debug
  elseif k=="escape" then love.event.quit() end
end
