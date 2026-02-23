-- main.lua — Bytecode VM + Components (Beginner)
local FIXED_DT, MAX_ITERS = 1/120, 8
local acc = 0

-- Components are plain tables with optional callbacks:
--   update(self, entity, dt) per fixed-timestep update
--   draw(self, entity, alpha) per render; alpha is interpolation factor
local function newComponent(component)
  component.enabled = (component.enabled ~= false)
  component.update  = component.update or function(self, entity, dt) end
  component.draw    = component.draw   or function(self, entity, alpha)  end
  return component
end

-- ---------- Simple components ----------
local Mover = {}
function Mover.new()
  return newComponent({
    update = function(self, entity, dt)
      -- Remember previous position for interpolation
      entity.px, entity.py = entity.x, entity.y
      -- Ensure velocity fields exist
      entity.vx, entity.vy = entity.vx or 0, entity.vy or 0
      -- Integrate position using velocity
      entity.x = entity.x + entity.vx * dt
      entity.y = entity.y + entity.vy * dt
    end
  })
end

local Renderer = {}
function Renderer.new(mode)
  return newComponent({
    mode = mode or "fill",
    draw = function(self, entity, alpha)
      -- Interpolate between previous and current physics state for smoothness
      local renderX = entity.px + (entity.x - entity.px) * alpha
      local renderY = entity.py + (entity.y - entity.py) * alpha
      love.graphics.setColor(entity.color or {1,1,1})
      love.graphics.rectangle(self.mode, renderX, renderY, entity.w, entity.h)
      love.graphics.setColor(1,1,1)
    end
  })
end

-- ---------- Bytecode VM ----------
-- Opcodes (small integers)
local OP = { SET_VX=1, SET_VY=2, WAIT=3, LOOP=4 }

local VM = {}
VM.__index = VM
function VM.new(code)
  -- code: flat number array: {OP, operand?, OP, operand?, ...}
  return setmetatable({ code=code, ip=1, waitSteps=0 }, VM)
end

function VM:step(entity)
  -- If we're in a WAIT, consume one fixed step
  if self.waitSteps > 0 then
    self.waitSteps = self.waitSteps - 1
    return
  end
  local op = self.code[self.ip]; if not op then return end
  self.ip = self.ip + 1

  if op == OP.SET_VX then
    local vx = self.code[self.ip]; self.ip = self.ip + 1
    entity.vx = vx
  elseif op == OP.SET_VY then
    local vy = self.code[self.ip]; self.ip = self.ip + 1
    entity.vy = vy
  elseif op == OP.WAIT then
    local steps = self.code[self.ip]; self.ip = self.ip + 1
    self.waitSteps = steps
  elseif op == OP.LOOP then
    local target = self.code[self.ip]; self.ip = target -- jump to index
  else
    -- Unknown opcode: stop safely
    self.ip = #self.code + 1
  end
end

-- Component that runs the VM once per fixed step
local ScriptedMotion = {}
function ScriptedMotion.new(code)
  return newComponent({
    vm = VM.new(code),
    update = function(self, entity, dt)
      self.vm:step(entity)
    end
  })
end

-- ---------- Entity ----------
local function newEntity(x, y, width, height, components)
  local entity = {
    x = x, y = y,
    px = x, py = y,
    w = width or 32, h = height or 32,
    comps = components or {},
    active = true,
    vx = 0, vy = 0,
    color = {0.8,1,0.6},
  }
  function entity:update(dt)
    for _, component in ipairs(self.comps) do
      if component.enabled and component.update then component:update(self, dt) end
    end
  end
  function entity:draw(alpha)
    for _, component in ipairs(self.comps) do
      if component.enabled and component.draw then component:draw(self, alpha) end
    end
  end
  return entity
end

-- ---------- World ----------
local entities = {}

-- Program: move right for 0.5s, left for 0.5s, loop.
-- We measure WAIT in fixed steps. At 120 Hz, 60 steps ≈ 0.5s.
local program = {
  OP.SET_VX,  120,
  OP.WAIT,     60,
  OP.SET_VX, -120,
  OP.WAIT,     60,
  OP.LOOP,      1,   -- jump back to first opcode (index 1)
}

local function fixedUpdate()
  for _, entity in ipairs(entities) do
    if entity.active then entity:update(FIXED_DT) end
  end
end

function love.load()
  love.window.setTitle("Bytecode VM Demo — Scripted Velocity")
  love.graphics.setBackgroundColor(0.08,0.09,0.12)
  local actor = newEntity(100, 200, 40, 28, {
    ScriptedMotion.new(program),
    Mover.new(),
    Renderer.new("fill"),
  })
  table.insert(entities, actor)
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
  for _, entity in ipairs(entities) do entity:draw(alpha) end
  love.graphics.print("Bytecode: SET_VX, WAIT, LOOP (flip direction every 0.5s)", 10, 10)
  love.graphics.print("Add keys to tweak opcodes for practice.", 10, 28)
end

function love.keypressed(k)
  if k=="escape" then love.event.quit() end
end
