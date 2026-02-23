# Lua and LOVE Game Engine Reference

## Table of Contents

1. [Lua Language Basics](#lua-language-basics)
2. [LOVE Game Engine Overview](#love-game-engine-overview)
3. [LOVE Callbacks](#love-callbacks)
4. [Graphics and Drawing](#graphics-and-drawing)
5. [Input Handling](#input-handling)
6. [Audio](#audio)
7. [File System](#file-system)
8. [Physics](#physics)
9. [Best Practices](#best-practices)
10. [Common Patterns](#common-patterns)

---

## Lua Language Basics

### Variables and Data Types

```lua
-- Variables (no declaration needed)
local x = 10          -- number
local name = "Hello"   -- string
local isTrue = true    -- boolean
local nothing = nil    -- nil (undefined)

-- Global vs Local
globalVar = "accessible everywhere"
local localVar = "only in current scope"
```

### Tables (Lua's main data structure)

```lua
-- Array-like table (1-indexed)
local fruits = {"apple", "banana", "orange"}
print(fruits[1])  -- "apple"

-- Dictionary-like table
local player = {
    name = "Player1",
    health = 100,
    x = 50,
    y = 100
}

-- Mixed table
local mixed = {
    "first",           -- [1]
    "second",          -- [2]
    name = "example",  -- ["name"]
    [42] = "answer"    -- [42]
}

-- Table methods
table.insert(fruits, "grape")  -- Add to end
table.remove(fruits, 1)        -- Remove first element
```

### Functions

```lua
-- Basic function
function greet(name)
    return "Hello, " .. name
end

-- Local function
local function add(a, b)
    return a + b
end

-- Anonymous function
local multiply = function(a, b)
    return a * b
end

-- Multiple return values
function getCoords()
    return 10, 20
end
local x, y = getCoords()
```

### Control Structures

```lua
-- If statements
if health > 50 then
    print("Healthy")
elseif health > 0 then
    print("Wounded")
else
    print("Dead")
end

-- For loops
for i = 1, 10 do
    print(i)
end

-- For loop with step
for i = 10, 1, -1 do
    print(i)
end

-- Iterate over table
for index, value in ipairs(fruits) do
    print(index, value)
end

-- Iterate over key-value pairs
for key, value in pairs(player) do
    print(key, value)
end

-- While loop
while health > 0 do
    health = health - 1
end
```

### String Operations

```lua
local str = "Hello World"
print(#str)                    -- Length: 11
print(string.upper(str))       -- "HELLO WORLD"
print(string.lower(str))       -- "hello world"
print(string.sub(str, 1, 5))   -- "Hello"

-- String concatenation
local greeting = "Hello" .. " " .. "World"

-- String formatting
local formatted = string.format("Health: %d/%d", 75, 100)
```

---

## LOVE Game Engine Overview

LOVE (LÖVE) is a 2D game framework for Lua that provides:

- Graphics rendering
- Audio playback
- Input handling
- Physics simulation
- File I/O
- Networking (basic)

### Project Structure

```
game/
├── main.lua          -- Entry point
├── conf.lua          -- Configuration (optional)
├── assets/
│   ├── images/
│   ├── sounds/
│   └── fonts/
└── src/
    ├── player.lua
    ├── enemy.lua
    └── utils.lua
```

### Configuration (conf.lua)

```lua
function love.conf(t)
    t.title = "My Game"
    t.window.width = 800
    t.window.height = 600
    t.window.resizable = true
    t.modules.physics = true
    t.modules.audio = true
end
```

---

## LOVE Callbacks

### Essential Callbacks

```lua
-- Called once at startup
function love.load()
    -- Initialize game state
    player = {x = 400, y = 300, speed = 200}
    enemies = {}
end

-- Called every frame
function love.update(dt)
    -- dt is delta time in seconds
    -- Update game logic
    if love.keyboard.isDown("left") then
        player.x = player.x - player.speed * dt
    end
end

-- Called every frame for rendering
function love.draw()
    -- Draw everything
    love.graphics.circle("fill", player.x, player.y, 20)
end
```

### Input Callbacks

```lua
-- Key pressed once
function love.keypressed(key)
    if key == "space" then
        -- Jump or shoot
    elseif key == "escape" then
        love.event.quit()
    end
end

-- Key released
function love.keyreleased(key)
    -- Handle key release
end

-- Mouse pressed
function love.mousepressed(x, y, button, istouch)
    if button == 1 then  -- Left click
        -- Handle left click
    end
end

-- Text input (for typing)
function love.textinput(text)
    -- Handle text input
end
```

---

## Graphics and Drawing

### Basic Drawing

```lua
function love.draw()
    -- Set color (RGB, 0-1 range)
    love.graphics.setColor(1, 0, 0)  -- Red

    -- Draw shapes
    love.graphics.rectangle("fill", 100, 100, 200, 150)
    love.graphics.circle("line", 300, 200, 50)
    love.graphics.line(0, 0, 100, 100)
    love.graphics.polygon("fill", 400, 100, 450, 200, 350, 200)

    -- Reset color to white
    love.graphics.setColor(1, 1, 1)
end
```

### Images

```lua
local playerImage

function love.load()
    playerImage = love.graphics.newImage("assets/player.png")
end

function love.draw()
    -- Draw image at position
    love.graphics.draw(playerImage, 100, 100)

    -- Draw with rotation and scale
    love.graphics.draw(playerImage, 200, 200, math.rad(45), 2, 2)

    -- Draw portion of image (quad)
    local quad = love.graphics.newQuad(0, 0, 32, 32, playerImage:getDimensions())
    love.graphics.draw(playerImage, quad, 300, 300)
end
```

### Text

```lua
local font

function love.load()
    font = love.graphics.newFont("assets/font.ttf", 24)
    love.graphics.setFont(font)
end

function love.draw()
    love.graphics.print("Hello World", 100, 100)

    -- Formatted text
    local text = love.graphics.newText(font, "Colored Text")
    love.graphics.draw(text, 100, 150)
end
```

### Transformations

```lua
function love.draw()
    love.graphics.push()  -- Save current transformation

    love.graphics.translate(400, 300)  -- Move origin
    love.graphics.rotate(math.rad(45)) -- Rotate 45 degrees
    love.graphics.scale(2, 2)          -- Scale 2x

    love.graphics.rectangle("fill", -25, -25, 50, 50)

    love.graphics.pop()   -- Restore transformation
end
```

---

## Input Handling

### Keyboard

```lua
function love.update(dt)
    -- Continuous input (held down)
    if love.keyboard.isDown("w", "up") then
        player.y = player.y - 100 * dt
    end
    if love.keyboard.isDown("s", "down") then
        player.y = player.y + 100 * dt
    end
    if love.keyboard.isDown("a", "left") then
        player.x = player.x - 100 * dt
    end
    if love.keyboard.isDown("d", "right") then
        player.x = player.x + 100 * dt
    end
end

function love.keypressed(key)
    -- Single press events
    if key == "space" then
        -- Jump
    end
end
```

### Mouse

```lua
function love.update(dt)
    local mouseX, mouseY = love.mouse.getPosition()

    if love.mouse.isDown(1) then  -- Left button
        -- Continuous mouse button
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then  -- Left click
        -- Single click event
    elseif button == 2 then  -- Right click
        -- Right click event
    end
end
```

### Gamepad

```lua
function love.update(dt)
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        local joystick = joysticks[1]

        -- Analog stick
        local leftX = joystick:getGamepadAxis("leftx")
        local leftY = joystick:getGamepadAxis("lefty")

        player.x = player.x + leftX * 200 * dt
        player.y = player.y + leftY * 200 * dt

        -- Buttons
        if joystick:isGamepadDown("a") then
            -- A button pressed
        end
    end
end
```

---

## Audio

### Sound Effects

```lua
local jumpSound

function love.load()
    jumpSound = love.audio.newSource("assets/jump.wav", "static")
end

function love.keypressed(key)
    if key == "space" then
        love.audio.play(jumpSound)
    end
end
```

### Music

```lua
local bgMusic

function love.load()
    bgMusic = love.audio.newSource("assets/music.ogg", "stream")
    bgMusic:setLooping(true)
    love.audio.play(bgMusic)
end
```

### Audio Control

```lua
-- Volume control (0.0 to 1.0)
love.audio.setVolume(0.5)

-- Source-specific volume
jumpSound:setVolume(0.8)

-- Pause/resume
bgMusic:pause()
bgMusic:play()
bgMusic:stop()
```

---

## File System

### Reading Files

```lua
-- Read entire file
local content = love.filesystem.read("data.txt")

-- Check if file exists
if love.filesystem.getInfo("save.dat") then
    -- File exists
end

-- Get directory contents
local files = love.filesystem.getDirectoryItems("assets")
for i, file in ipairs(files) do
    print(file)
end
```

### Writing Files

```lua
-- Write to file
love.filesystem.write("save.dat", "player_score=1000")

-- Append to file
love.filesystem.append("log.txt", "Game started\n")
```

### Save Data

```lua
-- Simple save system
function saveGame()
    local saveData = {
        playerLevel = player.level,
        playerScore = player.score,
        currentLevel = currentLevel
    }

    local serialized = ""
    for key, value in pairs(saveData) do
        serialized = serialized .. key .. "=" .. value .. "\n"
    end

    love.filesystem.write("save.dat", serialized)
end

function loadGame()
    if love.filesystem.getInfo("save.dat") then
        local content = love.filesystem.read("save.dat")
        -- Parse content and restore game state
    end
end
```

---

## Physics

### World Setup

```lua
local world
local player = {}

function love.load()
    love.physics.setMeter(64)  -- 64 pixels = 1 meter
    world = love.physics.newWorld(0, 9.81 * 64, true)  -- Gravity

    -- Create player physics body
    player.body = love.physics.newBody(world, 400, 300, "dynamic")
    player.shape = love.physics.newRectangleShape(32, 32)
    player.fixture = love.physics.newFixture(player.body, player.shape, 1)
    player.fixture:setRestitution(0.5)  -- Bounciness
end

function love.update(dt)
    world:update(dt)
end

function love.draw()
    love.graphics.rectangle("fill",
        player.body:getX() - 16,
        player.body:getY() - 16,
        32, 32)
end
```

### Collision Detection

```lua
function beginContact(a, b, collision)
    -- Called when two fixtures begin touching
    local userDataA = a:getUserData()
    local userDataB = b:getUserData()

    if userDataA == "player" and userDataB == "enemy" then
        -- Handle player-enemy collision
    end
end

function love.load()
    world:setCallbacks(beginContact, endContact, preSolve, postSolve)
end
```

---

## Best Practices

### Code Organization

```lua
-- main.lua
require("src/player")
require("src/enemy")
require("src/utils")

local gameState = "menu"  -- menu, playing, paused, gameover

function love.update(dt)
    if gameState == "playing" then
        player.update(dt)
        enemy.update(dt)
    end
end
```

### State Management

```lua
local states = {}
local currentState = nil

states.menu = {
    update = function(dt) end,
    draw = function() end,
    keypressed = function(key) end
}

states.game = {
    update = function(dt) end,
    draw = function() end,
    keypressed = function(key) end
}

function setState(state)
    currentState = states[state]
end

function love.update(dt)
    if currentState then
        currentState.update(dt)
    end
end
```

### Performance Tips

```lua
-- Pre-calculate values
local halfWidth = love.graphics.getWidth() / 2
local cos45 = math.cos(math.rad(45))

-- Avoid creating objects in update loop
function love.load()
    bullets = {}
end

function love.update(dt)
    -- Good: reuse existing table
    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        bullet.x = bullet.x + bullet.vx * dt
        if bullet.x > 800 then
            table.remove(bullets, i)
        end
    end
end

-- Use local references for frequently accessed globals
function love.update(dt)
    local lg = love.graphics
    local sin, cos = math.sin, math.cos
    -- Now use lg.draw, sin(), cos() instead
end
```

---

## Common Patterns

### Object-Oriented Programming

```lua
-- Class definition
local Player = {}
Player.__index = Player

function Player.new(x, y)
    local self = setmetatable({}, Player)
    self.x = x
    self.y = y
    self.health = 100
    return self
end

function Player:update(dt)
    -- Update player
end

function Player:draw()
    love.graphics.circle("fill", self.x, self.y, 20)
end

-- Usage
local player = Player.new(400, 300)
```

### Timer System

```lua
local Timer = {}

function Timer.new(duration, callback)
    return {
        duration = duration,
        time = 0,
        callback = callback,
        finished = false
    }
end

function Timer.update(timer, dt)
    if not timer.finished then
        timer.time = timer.time + dt
        if timer.time >= timer.duration then
            timer.finished = true
            timer.callback()
        end
    end
end

-- Usage
local explosionTimer = Timer.new(2.0, function()
    -- Explode after 2 seconds
end)
```

### Resource Manager

```lua
local Resources = {}
local images = {}
local sounds = {}

function Resources.loadImage(name, path)
    images[name] = love.graphics.newImage(path)
end

function Resources.getImage(name)
    return images[name]
end

function Resources.loadSound(name, path)
    sounds[name] = love.audio.newSource(path, "static")
end

function Resources.getSound(name)
    return sounds[name]
end

-- Usage
Resources.loadImage("player", "assets/player.png")
local playerImg = Resources.getImage("player")
```

### Scene/Screen Management

```lua
local Gamestate = require("gamestate")

local menu = {}
local game = {}

function menu:update(dt) end
function menu:draw() end
function menu:keypressed(key)
    if key == "return" then
        Gamestate.switch(game)
    end
end

function game:update(dt) end
function game:draw() end
function game:keypressed(key)
    if key == "escape" then
        Gamestate.switch(menu)
    end
end

function love.load()
    Gamestate.registerEvents()
    Gamestate.switch(menu)
end
```

This reference covers the essential aspects of both Lua and the LOVE game engine. Use it as a quick lookup when developing your games!
