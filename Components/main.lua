--[[
  main.lua — Component pattern (Beginner)

  What this file shows
  - A tiny “component pattern” on top of LÖVE (Love2D): entities hold a list of
    components; each component can update and/or draw the entity.
  - A fixed-timestep update loop with render-time interpolation for smooth
    motion on variable refresh rates.
  - Note on double buffering: you don’t need to implement it yourself in LÖVE.
    LÖVE already renders love.draw to an off-screen back buffer and swaps it to
    the screen each frame. The “accumulator + alpha” you see here is for time
    smoothing, not manual back-buffer management.

  New to Lua and LÖVE?
  - Lua tables are used for objects. A function can add fields to a table and
    return it (like a constructor). The colon syntax obj:method(x) passes obj as
    the first argument (self).
  - LÖVE calls love.load once, love.update(dt) each frame with elapsed seconds,
    and love.draw each frame to render. You run it with the `love` executable.
]]

-- Fixed timestep settings
-- Update 120 times per second at most, but don’t do more than 8 catch-up
-- iterations in a single frame (prevents spiral of death after pauses).
local FIXED_DT, MAX_ITERS = 1/120, 8

-- Accumulator stores leftover time not yet consumed by fixed updates.
local acc = 0

-- ==== Component base ========================================================
-- Create a minimal component object with optional hooks:
-- - enabled: turn component on/off (default true)
-- - update(self, e, dt): per-physics-step behavior
-- - draw(self, e, alpha): per-render behavior (alpha = interpolation factor)
local function newComponent(t)
  t.enabled = (t.enabled ~= false)
  t.update = t.update or function(self, e, dt) end
  t.draw = t.draw or function(self, e, alpha) end
  return t
end

-- ==== Example components ====================================================

-- Mover: applies a constant velocity stored on the component itself.
-- Note: Another common pattern is to read e.vx/e.vy (entity velocity) here so
-- that other components (e.g., Bouncer) can change direction. This demo keeps
-- velocity on the component to stay simple; see comments in Bouncer below.
local Mover = {}
function Mover.new(vx, vy)
  return newComponent({
    vx = vx or 0,
    vy = vy or 0,
    update = function(self, e, dt)
      -- Store previous position for render interpolation
      e.px, e.py = e.x, e.y
      -- Advance using the component’s velocity
      e.x = e.x + self.vx * dt
      e.y = e.y + self.vy * dt
    end
  })
end

-- Bouncer: pushes the rectangle back inside the window and flips the entity’s
-- e.vx/e.vy signs when it hits an edge. This demonstrates components
-- communicating via fields on the entity. If you want bounces to affect motion
-- when using Mover, have Mover use e.vx/e.vy instead of self.vx/self.vy.
local Bouncer = {}
function Bouncer.new(margin)
  return newComponent({
    margin = margin or 0,
    update = function(self, e, dt)
      local W, H = love.graphics.getWidth(), love.graphics.getHeight()
      if e.x < self.margin then e.x = self.margin; e.vx = math.abs(e.vx) end
      if e.x + e.w > W - self.margin then e.x = W - self.margin - e.w; e.vx = -math.abs(e.vx) end
      if e.y < self.margin then e.y = self.margin; e.vy = math.abs(e.vy) end
      if e.y + e.h > H - self.margin then e.y = H - self.margin - e.h; e.vy = -math.abs(e.vy) end
    end
  })
end

-- Velocity: makes sure e.vx/e.vy exist so other components can read/modify.
local Velocity = {}
function Velocity.new()
  return newComponent({
    update = function(self, e, dt)
      -- Expose velocity on entity for other components to use (e.g., Bouncer)
      e.vx = e.vx or 0
      e.vy = e.vy or 0
    end
  })
end

-- Renderer: draws a rectangle for the entity. We use render-time interpolation
-- so visuals are smooth even if physics runs at a fixed rate.
local Renderer = {}
function Renderer.new(mode)
  return newComponent({
    mode = mode or "fill",
    draw = function(self, e, a)
      -- Interpolated position between last physics state (px/py) and current
      local rx = e.px + (e.x - e.px) * a
      local ry = e.py + (e.y - e.py) * a
      love.graphics.rectangle(self.mode, rx, ry, e.w, e.h)
    end
  })
end

-- Blink: toggles an outline every `period` seconds.
local Blink = {}
function Blink.new(period)
  return newComponent({
    t = 0,
    period = period or 0.5,
    on = true,
    update = function(self, e, dt)
      self.t = self.t + dt
      if self.t >= self.period then
        self.t = 0
        self.on = not self.on
      end
    end,
    draw = function(self, e, a)
      if self.on then
        local rx = e.px + (e.x - e.px) * a
        local ry = e.py + (e.y - e.py) * a
        love.graphics.rectangle("line", rx - 2, ry - 2, e.w + 4, e.h + 4)
      end
    end
  })
end

-- ==== Entity ================================================================
-- Simple entity “class”: a table of data with a list of components.
-- Fields:
--   x, y  current position (top-left)
--   px,py previous position (for interpolation)
--   w, h  size
--   comps array of components (objects with update/draw)
--   active whether to update
--   vx, vy optional velocity stored on the entity (used by Bouncer, etc.)
local function newEntity(x, y, w, h, comps)
  local e = {
    x = x, y = y,
    px = x, py = y,
    w = w or 32, h = h or 32,
    comps = comps or {},
    active = true,
    vx = 120, vy = 80,
  }
  function e:add(c)
    table.insert(self.comps, c)
  end
  function e:update(dt)
    for _, c in ipairs(self.comps) do
      if c.enabled and c.update then c:update(self, dt) end
    end
  end
  function e:draw(a)
    for _, c in ipairs(self.comps) do
      if c.enabled and c.draw then c:draw(self, a) end
    end
  end
  return e
end

-- ==== World / fixed update ==================================================
local entities = {}

-- Run one fixed-duration physics step for all active entities.
local function fixedUpdate()
  for _, e in ipairs(entities) do
    if e.active then e:update(FIXED_DT) end
  end
end

-- ==== LÖVE callbacks ========================================================
function love.load()
  love.window.setTitle("Component Pattern Demo")
  love.graphics.setBackgroundColor(0.08, 0.09, 0.12)

  -- Create two example entities with different component mixes.
  local player = newEntity(100, 100, 36, 36, {
    Velocity.new(),
    Mover.new(120, 0),
    Bouncer.new(0),
    Renderer.new("fill"),
    Blink.new(0.4),
  })

  local enemy = newEntity(300, 220, 32, 32, {
    Velocity.new(),
    Mover.new(0, 80),
    Bouncer.new(0),
    Renderer.new("line"),
  })

  table.insert(entities, player)
  table.insert(entities, enemy)
end

function love.update(dt)
  -- Clamp dt to avoid huge catch-up after alt-tabbing or breakpoints
  dt = math.min(dt, 0.10)
  acc = acc + dt

  -- Consume accumulator in fixed-size steps.
  local it = 0
  while acc >= FIXED_DT and it < MAX_ITERS do
    fixedUpdate()
    acc = acc - FIXED_DT
    it = it + 1
  end

  -- If we hit the iteration cap, drop any excess time to keep the game
  -- responsive. This trades some accuracy for stability under heavy load.
  if it == MAX_ITERS then acc = 0 end
end

function love.draw()
  -- Interpolation factor in [0..1]: how far we are to the next physics tick.
  local a = acc / FIXED_DT
  if a > 1 then a = 1 end

  love.graphics.setColor(1, 1, 1)
  for _, e in ipairs(entities) do e:draw(a) end

  -- Heads-up display
  love.graphics.print("Components: Velocity, Mover, Bouncer, Renderer, Blink", 10, 10)
  love.graphics.print("Press [1] toggle Blink on first entity", 10, 28)

  -- Note: LÖVE handles double buffering automatically. Everything drawn here
  -- goes to the back buffer; LÖVE swaps it to the screen after love.draw ends.
end

function love.keypressed(k)
  if k == "1" then
    -- Toggle the last component on the first entity (Blink)
    local c = entities[1].comps[#entities[1].comps]
    c.enabled = not c.enabled
  elseif k == "escape" then
    love.event.quit()
  end
end
