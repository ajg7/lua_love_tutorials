--[[
  Double Buffer demo (LÖVE 2D + Lua)

  What you see: a simple cellular-style diffusion where energy spreads from
  cells you "paint" with the mouse. The important concept is double buffering
  (also called ping-pong buffers):

  - We always READ from one grid (readBuffer) and WRITE results into another
    grid (writeBuffer) within a simulation step. This prevents newly written
    values from contaminating neighbor reads in the same step.
  - After processing, we SWAP the buffers so the fresh results become the
    read source for the next step.

  LÖVE (love2d) basics used here:
  - love.update(dt): game loop tick; we run a fixed-timestep simulation inside
    it for stability and determinism.
  - love.draw(): render the current readBuffer to the screen.
  - love.mousemoved/pressed/released: track painting input.
  - love.keypressed: tweak parameters at runtime.

  Lua quick notes:
  - Arrays are 1-based (we index from 1, not 0).
  - Tables are used for dynamic arrays and maps. Our grid is a table-of-tables
    indexed as grid[y][x] (row-major: first index is y/row, second is x/col).
]]

-- Fixed-timestep simulation settings
local FIXED_DT, MAX_ITERS = 1/20, 8
local acc = 0

-- Visual layout
local CELL = 8
local W, H = 800, 600

local GW, GH = math.floor(W / CELL), math.floor(H / CELL)

-- Allocate a 2D grid as grid[y][x] with zeros.
local function makeGrid()
  local grid = {}
  for y = 1, GH do
    grid[y] = {}
    for x = 1, GW do
      grid[y][x] = 0
    end
  end
  return grid
end

local readBuffer = makeGrid()
local writeBuffer = makeGrid()

-- Simulation parameters
local decay = 0.90
local spread = 0.025
local brush = 1.0

-- Mouse input state (we add energy where the mouse is)
local mouseX, mouseY, painting = W / 2, H / 2, false
function love.mousemoved(x,y) mouseX, mouseY = x, y end
function love.mousepressed()  painting = true  end
function love.mousereleased() painting = false end

-- One fixed simulation step: read from readBuffer, write into writeBuffer, then swap.
local function fixedUpdate()
  -- Convert pixel mouse position to cell indices (1-based)
  local mx = math.floor(mouseX / CELL) + 1
  local my = math.floor(mouseY / CELL) + 1

  for y = 1, GH do
    local up   = math.max(1, y - 1)
    local down = math.min(GH, y + 1)
    for x = 1, GW do
      local left  = math.max(1, x - 1)
      local right = math.min(GW, x + 1)

      -- Current cell value from READ buffer
      local v = readBuffer[y][x]
      -- Sum of 4-neighborhood (up, down, left, right)
      local neighbors = readBuffer[up][x] + readBuffer[down][x] + readBuffer[y][left] + readBuffer[y][right]
      -- Diffusion-like update with decay (retain) and spread (incoming)
      local nv = v * decay + neighbors * spread

      -- Mouse paint: only affect the WRITE side to keep reads consistent this step
      if painting and math.abs(x - mx) <= 1 and math.abs(y - my) <= 1 then
        nv = math.min(1.0, nv + brush)
      end

      writeBuffer[y][x] = nv
    end
  end
  -- SWAP buffers (ping-pong)
  readBuffer, writeBuffer = writeBuffer, readBuffer
end

function love.update(dt)
  -- Cap dt to avoid huge catch-up after pauses
  dt = math.min(dt, 0.10)
  acc = acc + dt
  local it = 0
  -- Run multiple fixed steps to catch up if needed, but clamp to avoid spiral of death
  while acc >= FIXED_DT and it < MAX_ITERS do
    fixedUpdate()
    acc, it = acc - FIXED_DT, it + 1
  end
  if it == MAX_ITERS then acc = 0 end
end


function love.draw()
  local a = acc / FIXED_DT; if a > 1 then a = 1 end  -- (not used, placeholder for interpolation patterns)

  -- Draw from the READ buffer only
  for y = 1, GH do
    for x = 1, GW do
      local v = readBuffer[y][x]
      if v > 0.001 then
        -- LÖVE colors are 0..1; use grayscale based on cell value
        love.graphics.setColor(v, v, v)
        love.graphics.rectangle("fill", (x - 1) * CELL, (y - 1) * CELL, CELL, CELL)
      end
    end
  end

  -- UI text
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print("Double Buffer demo — Click/drag to paint light", 10, 10)
  love.graphics.print(string.format("decay=%.2f  spread=%.3f  (Q/A, W/S)", decay, spread), 10, 28)
end

function love.keypressed(k)
  if k == "escape" then love.event.quit()
  elseif k == "q" then decay = math.min(0.99, decay + 0.01)
  elseif k == "a" then decay = math.max(0.50, decay - 0.01)
  elseif k == "w" then spread = math.min(0.050, spread + 0.005)
  elseif k == "s" then spread = math.max(0.000, spread - 0.005)
  end
end
