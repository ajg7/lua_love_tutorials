-- main.lua — Subclass Sandbox (Beginner)
local FIXED_DT, MAX_ITERS = 1/120, 8
local acc = 0
local WINDOW_WIDTH, WINDOW_HEIGHT = 800, 600

-- =============== Base "class" ===============
local Actor = {}
Actor.__index = Actor

local function clamp(value, minValue, maxValue)
  return math.max(minValue, math.min(maxValue, value))
end

function Actor:new(x, y, width, height, behaveFn)
  return setmetatable({
    x = x, y = y, px = x, py = y,
    w = width or 32, h = height or 32,
    vx=0, vy=0, speed=140,
    behave = behaveFn or function(sb, dt) end, -- "subclass hook"
  }, Actor)
end

-- Provide a small, safe API to the behavior ("subclass").
function Actor:makeSandbox()
  local selfRef = self  -- capture
  return {
    -- Set absolute velocity (safe primitive)
    setVelocity = function(vx, vy)
      selfRef.vx, selfRef.vy = vx or 0, vy or 0
    end,
    -- Add a small nudge (safe, capped)
    nudge = function(dx, dy)
      selfRef.vx = selfRef.vx + (dx or 0)
      selfRef.vy = selfRef.vy + (dy or 0)
    end,
    -- Move in a direction at the actor's speed (normalized input)
    moveDir = function(dx, dy)
      local mag = math.sqrt((dx or 0)^2 + (dy or 0)^2)
      if mag > 0 then
        selfRef.vx = (dx/mag) * selfRef.speed
        selfRef.vy = (dy/mag) * selfRef.speed
      else
        selfRef.vx, selfRef.vy = 0, 0
      end
    end,
    -- Read-only accessors
    getPos = function() return selfRef.x, selfRef.y end,
    getBounds = function() return 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT end,
  }
end

function Actor:update(dt)
  -- 1) snapshot for render interpolation
  self.px, self.py = self.x, self.y
  -- 2) let the “subclass” run only via the sandbox
  local sb = self:makeSandbox()
  self.behave(sb, dt)
  -- 3) base enforces invariants (physics & clamping)
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
  self.x = clamp(self.x, 0, WINDOW_WIDTH - self.w)
  self.y = clamp(self.y, 0, WINDOW_HEIGHT - self.h)
end

function Actor:draw(alpha)
  local renderX = self.px + (self.x - self.px) * alpha
  local renderY = self.py + (self.y - self.py) * alpha
  love.graphics.rectangle("fill", renderX, renderY, self.w, self.h)
end

-- =============== “Subclass” behaviors (just functions) ===============
local function Patroller(sandbox, dt)
  -- Move left until x<80, then right until x>W-80, repeat
  local x = select(1, sandbox.getPos())
  local left, _, right, _ = sandbox.getBounds()
  if x < 80 then
    sandbox.moveDir(1, 0)
  elseif x > (right - 80) then
    sandbox.moveDir(-1, 0)
  end
end

local function ZigZag(sandbox, dt)
  -- Oscillate vertically while drifting right
  local timeNow = love.timer.getTime()
  local dirY = math.sin(timeNow * 2.0) > 0 and 1 or -1
  sandbox.setVelocity(110, dirY * 90)
end

-- =============== World scaffolding ===============
local actors = {}

local function fixedUpdate()
  for _, actor in ipairs(actors) do
    actor:update(FIXED_DT)
  end
end

function love.load()
  love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
  love.graphics.setBackgroundColor(0.08, 0.09, 0.12)
  table.insert(actors, Actor:new(100, 200, 36, 36, Patroller))
  table.insert(actors, Actor:new(200, 120, 28, 28, ZigZag))
end

function love.update(dt)
  dt = math.min(dt, 0.10)
  acc = acc + dt
  local iterations = 0
  while acc >= FIXED_DT and iterations < MAX_ITERS do
    fixedUpdate()
    acc = acc - FIXED_DT
    iterations = iterations + 1
  end
  if iterations == MAX_ITERS then acc = 0 end
end

function love.draw()
  local alpha = acc / FIXED_DT
  if alpha > 1 then alpha = 1 end
  love.graphics.setColor(1,1,1)
  for _, actor in ipairs(actors) do
    actor:draw(alpha)
  end
  love.graphics.print("Subclass Sandbox: Patroller & ZigZag via safe API", 10, 10)
end

function love.keypressed(k)
  if k=="escape" then love.event.quit() end
end
