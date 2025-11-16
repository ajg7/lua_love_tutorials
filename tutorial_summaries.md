# LÖVE Tutorial Repo – 80/20 Summaries

This file gives short "80/20" summaries of each tutorial folder: what idea it teaches, a minimal code sketch, and one practical game-dev use case.

---

## Table of Contents

- [LÖVE Tutorial Repo – 80/20 Summaries](#löve-tutorial-repo--8020-summaries)
  - [Table of Contents](#table-of-contents)
  - [Game_Loop – Fixed Timestep \& Interpolation](#game_loop--fixed-timestep--interpolation)
  - [Common_Patterns – Command, Flyweight, Observer, Prototype, Singleton, State](#common_patterns--command-flyweight-observer-prototype-singleton-state)
  - [Components – Entity-Component System (Lite)](#components--entity-component-system-lite)
  - [Object_Pool – Reusing Objects](#object_pool--reusing-objects)
  - [Free_List_Object_Pool – Pool with Free List](#free_list_object_pool--pool-with-free-list)
  - [Double_Buffer – Time, Not Rendering](#double_buffer--time-not-rendering)
  - [Dirty_Flag – Rebuild Only When Changed](#dirty_flag--rebuild-only-when-changed)
  - [Event_Queue – Decoupled Messaging](#event_queue--decoupled-messaging)
  - [Service_Locator – Swappable Services](#service_locator--swappable-services)
  - [Subclass_Sandbox – Controlled Inheritance](#subclass_sandbox--controlled-inheritance)
  - [Type_Object – Types as Data](#type_object--types-as-data)
  - [Update_Method – Objects Own Their Update](#update_method--objects-own-their-update)
  - [Data_Locality_AoS_vs_SoA – Cache-Friendly Layouts](#data_locality_aos_vs_soa--cache-friendly-layouts)
  - [Bytecode – Lua Under the Hood](#bytecode--lua-under-the-hood)
  - [Event_Queue vs Service_Locator vs Observer (Quick Contrast)](#event_queue-vs-service_locator-vs-observer-quick-contrast)

---

## Game_Loop – Fixed Timestep & Interpolation

**Core idea (80/20):** Run game logic at a fixed rate for stable physics, while rendering as often as possible using interpolation so motion stays smooth even when FPS varies.

```lua
local FIXED_DT, MAX_ITERS = 1/120, 8
local acc = 0

function love.update(dt)
  dt = math.min(dt, 0.10)
  acc = acc + dt
  local it = 0
  while acc >= FIXED_DT and it < MAX_ITERS do
    fixedUpdate(FIXED_DT)
    acc, it = acc - FIXED_DT, it + 1
  end
  if it == MAX_ITERS then acc = 0 end
end

function love.draw()
  local alpha = math.min(1, acc / FIXED_DT)
  drawWorld(alpha)
end
```

**Practical example:** A top-down shooter where bullets and enemies must move consistently on every machine. Fixed timestep keeps collision detection reliable; interpolation prevents stutter when a streamer’s PC briefly drops frames.

---

## Common_Patterns – Command, Flyweight, Observer, Prototype, Singleton, State

**Core idea (80/20):** Demonstrates several patterns together: commands for undoable input, flyweight for many light objects sharing data, observer for UI updates, prototype for cloning entities, singleton for global config, and state machine for player behavior.

```lua
-- Command pattern: input as undoable commands
local function MoveCommand(dx, dy)
  return {
    execute = function(self)
      self.prev = { x = player.x, y = player.y }
      player:move(dx, dy)
    end,
    undo = function(self)
      if self.prev then
        player.x, player.y = self.prev.x, self.prev.y
      end
    end
  }
end

history = {}
local function doCommand(cmd)
  cmd:execute()
  table.insert(history, cmd)
end
```

**Practical example:** A level editor for a platformer: moving platforms, placing enemies, resizing tiles, etc. Each edit is a command so you can support Ctrl+Z/Redo without special cases, and prototype lets you stamp out new enemies from a base template.

---

## Components – Entity-Component System (Lite)

**Core idea (80/20):** Entities are just data; behavior lives in reusable components that update/draw those entities. You mix components to build different entities without deep inheritance trees.

```lua
local function newComponent(c)
  c.update = c.update or function(self,e,dt) end
  c.draw   = c.draw   or function(self,e,a)  end
  return c
end

local function newEntity(x,y,w,h, comps)
  local e = { x=x, y=y, px=x, py=y, w=w, h=h, comps=comps or {} }
  function e:update(dt)
    for _,c in ipairs(self.comps) do c:update(self, dt) end
  end
  function e:draw(alpha)
    for _,c in ipairs(self.comps) do c:draw(self, alpha) end
  end
  return e
end

local Mover = {}
function Mover.new(vx,vy)
  return newComponent({
    vx=vx, vy=vy,
    update=function(self,e,dt)
      e.px,e.py = e.x,e.y
      e.x = e.x + self.vx*dt
      e.y = e.y + self.vy*dt
    end
  })
end
```

**Practical example:** A roguelike where enemies and items can freely combine behaviors: `Health`, `Shooter`, `Exploder`, `Flying`, `Patrol`. You can give a bat both `Flying` + `Shooter` without a complex enemy class hierarchy.

---

## Object_Pool – Reusing Objects

**Core idea (80/20):** Pre-allocate a fixed number of objects (like particles) and reuse them instead of constantly creating/destroying. This avoids garbage-collection spikes and keeps performance stable.

```lua
local Particle = {}
Particle.__index = Particle
function Particle:new()
  return setmetatable({ x=0,y=0,vx=0,vy=0,life=0 }, Particle)
end
function Particle:init(x,y,vx,vy,life)
  self.x,self.y,self.vx,self.vy,self.life = x,y,vx,vy,life
end
function Particle:update(dt)
  if self.life <= 0 then return end
  self.x = self.x + self.vx*dt
  self.y = self.y + self.vy*dt
  self.life = self.life - dt
end
function Particle:inUse() return self.life > 0 end

local Pool = { items = {}, size = 200 }
function Pool:init()
  for i=1,self.size do self.items[i] = Particle:new() end
end
function Pool:create(x,y,vx,vy,life)
  for _,p in ipairs(self.items) do
    if not p:inUse() then p:init(x,y,vx,vy,life); return p end
  end
end
```

**Practical example:** A bullet-hell boss fight with hundreds of projectiles. Bullets are recycled from a pool instead of allocated per shot, preventing frame drops mid-fight on low-end hardware.

---

## Free_List_Object_Pool – Pool with Free List

**Core idea (80/20):** Same goal as object pool, but tracks free indices in a list so allocation is O(1) and scanning the pool each time is avoided.

```lua
local Pool = { items = {}, free = {}, size = 256 }

function Pool:init()
  for i=1,self.size do
    self.items[i] = Particle:new()
    self.free[#self.free+1] = i
  end
end

function Pool:create(x,y,vx,vy,life)
  local idx = table.remove(self.free)  -- pop last free slot
  if not idx then return nil end
  local p = self.items[idx]
  p:init(x,y,vx,vy,life)
  return p, idx
end

function Pool:release(idx)
  self.items[idx].life = 0
  self.free[#self.free+1] = idx
end
```

**Practical example:** A networked arena game where you spawn/despawn many temporary effects (hit markers, damage numbers, shell casings). A free-list pool keeps allocation cost stable as the match gets hectic.

---

## Double_Buffer – Time, Not Rendering

**Core idea (80/20):** Clarifies that LÖVE already double-buffers rendering; this example focuses on using previous/current state for temporal "double buffering" (interpolation) rather than manual back-buffer images.

```lua
-- Store previous state in update
function fixedUpdate(dt)
  player.px, player.py = player.x, player.y
  player.x = player.x + player.vx * dt
end

-- Use both states in draw
function love.draw()
  local alpha = acc / FIXED_DT
  local x = player.px + (player.x - player.px) * alpha
  love.graphics.rectangle("fill", x, player.y, player.w, player.h)
end
```

**Practical example:** A racing game where cars respond to physics at a fixed rate but still look ultra-smooth on high-refresh monitors because their positions are interpolated between physics ticks.

---

## Dirty_Flag – Rebuild Only When Changed

**Core idea (80/20):** Mark expensive data as "dirty" and only recompute/rebuild when necessary, not every frame.

```lua
local HUD = { dirty = true, text = "", canvas = nil }

function HUD:setScore(score)
  self.text = "Score: "..score
  self.dirty = true
end

function HUD:rebuild()
  if not self.dirty then return end
  love.graphics.setCanvas(self.canvas)
  love.graphics.clear(0,0,0,0)
  love.graphics.print(self.text, 10, 10)
  love.graphics.setCanvas()
  self.dirty = false
end

function HUD:draw(x,y)
  self:rebuild()
  love.graphics.draw(self.canvas, x, y)
end
```

**Practical example:** An RPG inventory screen where the layout is expensive to render (icons, text, filters). You only rebuild the inventory canvas when items change, not every frame while it’s open.

---

## Event_Queue – Decoupled Messaging

**Core idea (80/20):** Use a queue of events (simple tables) to decouple systems. Producers push events; consumers process them later, often in a central place.

```lua
local events = {}

function emit(ev)
  events[#events+1] = ev
end

local function processEvents()
  for i,ev in ipairs(events) do
    if ev.type == "damage" then
      applyDamage(ev.target, ev.amount)
    elseif ev.type == "spawn" then
      spawnEnemy(ev.kind, ev.x, ev.y)
    end
  end
  events = {}
end

function fixedUpdate(dt)
  updateWorld(dt)
  processEvents()
end
```

**Practical example:** A tower-defense game where bullets, towers, and enemies all emit events like `damage`, `slow`, `gold_reward`. The main simulation processes these events in order, keeping game logic centralized and easier to debug.

---

## Service_Locator – Swappable Services

**Core idea (80/20):** A global locator provides services (like audio) without callers knowing the exact implementation. Often paired with a Null object for safe no-op behavior.

```lua
local Locator = { _audio = nil }
function Locator.provideAudio(svc) Locator._audio = svc end
function Locator.getAudio() return Locator._audio end

local NullAudio = {}
function NullAudio:play(name) end

local BeepAudio = {}
function BeepAudio:play(name)
  -- play with love.audio here
end

-- elsewhere
Locator.provideAudio(BeepAudio)  -- or NullAudio
Locator.getAudio():play("hit")
```

**Practical example:** A game that can run with or without sound (e.g., on a web build or muted kiosk). All gameplay code calls `Locator.getAudio():play("shoot")` and doesn’t care whether real audio or a silent stub is in use.

---

## Subclass_Sandbox – Controlled Inheritance

**Core idea (80/20):** Demonstrates using metatables to simulate inheritance and sandbox what child classes are allowed to touch, instead of giving full access to parent internals.

```lua
local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(x,y)
  return setmetatable({ x=x, y=y, hp=10 }, Enemy)
end

local FastEnemy = setmetatable({}, { __index = Enemy })
FastEnemy.__index = FastEnemy

function FastEnemy.new(x,y)
  local e = Enemy.new(x,y)
  e.speed = 220
  return setmetatable(e, FastEnemy)
end
```

**Practical example:** A shmup with many enemy variants (`SlowEnemy`, `FastEnemy`, `BossEnemy`) sharing base behavior but overriding specific methods (movement pattern, attack). A sandbox ensures mods or scripts can extend enemies without breaking core engine fields.

---

## Type_Object – Types as Data

**Core idea (80/20):** Represent types as data tables ("type objects") instead of big switch statements. Instances point to their type for stats and behavior.

```lua
local EnemyType = {
  grunt = { hp=10, speed=80 },
  tank  = { hp=40, speed=40 },
}

local Enemy = {}
Enemy.__index = Enemy
function Enemy.new(kind, x, y)
  local t = EnemyType[kind]
  local e = { type = t, x=x, y=y, hp=t.hp }
  return setmetatable(e, Enemy)
end

function Enemy:update(dt)
  self.x = self.x + self.type.speed * dt
end
```

**Practical example:** A card game where each card references a `CardType` with its stats and rules. Changing a type (e.g., rebalancing a spell) automatically updates behavior for all instances without touching their stored data.

---

## Update_Method – Objects Own Their Update

**Core idea (80/20):** Each object has its own `update` method, often stored on its metatable, so the main loop just calls `obj:update(dt)` instead of big if/switch blocks.

```lua
local Enemy = {}
Enemy.__index = Enemy
function Enemy.new(x,y)
  return setmetatable({ x=x, y=y, vx=60 }, Enemy)
end
function Enemy:update(dt)
  self.x = self.x + self.vx * dt
end

local enemies = { Enemy.new(10,50), Enemy.new(30,80) }

local function fixedUpdate(dt)
  for _,e in ipairs(enemies) do e:update(dt) end
end
```

**Practical example:** A platformer where `Player`, `Slime`, `Bat`, `Coin`, and `Checkpoint` all have their own `update` methods. The main loop doesn’t need to know the details; it just calls `update` on everything.

---

## Data_Locality_AoS_vs_SoA – Cache-Friendly Layouts

**Core idea (80/20):** Shows difference between Array-of-Structs (AoS: one table per entity) and Struct-of-Arrays (SoA: separate arrays for positions, velocities etc.) for data locality and performance.

```lua
-- AoS
local balls = {}
balls[1] = { x=0, y=0, vx=1, vy=2 }

-- SoA
local bx, by, bvx, bvy = {}, {}, {}, {}

for i=1,N do
  bx[i], by[i], bvx[i], bvy[i] = 0,0,1,2
end

-- SoA update is very cache friendly
for i=1,N do
  bx[i] = bx[i] + bvx[i]*dt
  by[i] = by[i] + bvy[i]*dt
end
```

**Practical example:** A space sim with thousands of asteroids. Using SoA for positions/velocities lets you update them in tight loops and keep FPS high, especially on low-end laptops.

---

## Bytecode – Lua Under the Hood

**Core idea (80/20):** Explores Lua bytecode / compiled chunks to show what your scripts become at runtime, useful for understanding performance and sandboxing.

```lua
local fn = load("return 1+2")  -- compiles to bytecode
print(fn())                      -- 3

-- In real examples you might dump bytecode or inspect it,
-- but usually you just care that Lua compiles your strings into reusable chunks.
```

**Practical example:** A game that loads user-made scripts for modding. Understanding bytecode and `load` helps you sandbox scripts and precompile them at startup to avoid stutters mid-game.

---

## Event_Queue vs Service_Locator vs Observer (Quick Contrast)

- **Event Queue:** Pushes time-ordered messages like `damage`, `spawn`, `pickup`; processed later, good for decoupling gameplay actions.
- **Observer:** Objects directly subscribe to a subject and react immediately when it changes (e.g., HUD observing `Score`).
- **Service Locator:** A global registry to _find_ services (audio, save system) without each caller knowing implementation.

Each appears in this repo in a minimal, game-focused form so you can mix and match for your own projects.
